local ngx_now = ngx.now
local req_get_method = ngx.req.get_method
local req_start_time = ngx.req.start_time
local req_get_headers = ngx.req.get_headers
local res_get_headers = ngx.resp.get_headers
local cjson = require "cjson"
local cjson_safe = require "cjson.safe"
local _M = {}

local base64 = require "kong.plugins.zenskar.base64"
local helpers = require "kong.plugins.zenskar.helpers"
local client_ip = require "kong.plugins.zenskar.ip_resolver"

function mask_body(body, masks)
  if masks == nil then return body end
  if body == nil then return body end
  for mask_key, mask_value in pairs(masks) do
    if body[mask_value] ~= nil then body[mask_value] = nil end
      for body_key, body_value in next, body do
          if type(body_value)=="table" then mask_body(body_value, masks) end
      end
  end
  return body
end

function base64_encode_body(body)
  return base64.encode(body), 'base64'
end

function is_valid_json(body)
  return type(body) == "string" 
      and string.sub(body, 1, 1) == "{" or string.sub(body, 1, 1) == "["
end

function mask_headers(headers, mask_fields)
  local mask_headers = nil
    
  for k,v in pairs(mask_fields) do
    mask_fields[k] = v:lower()
  end

  local ok, mask_result = pcall(mask_body, headers, mask_fields)
  if not ok then
    mask_headers = headers
  else
    mask_headers = mask_result
  end
  return mask_headers
end

function parse_body(headers, body, mask_fields, conf)
  local body_entity = nil
  local body_transfer_encoding = nil
  if headers["content-type"] ~= nil and string.find(headers["content-type"], "json") and is_valid_json(body) then 
    body_entity, body_transfer_encoding = process_data(body, mask_fields)
	else
      body_entity, body_transfer_encoding = base64_encode_body(body)
  end
  return body_entity, body_transfer_encoding
end

function mask_body_fields(body_masks_config, deprecated_body_masks_config)
  if next(body_masks_config) == nil then
    return deprecated_body_masks_config
  else
    return body_masks_config
  end
end

function _M.serialize(ngx, conf)
  local zenskar_ctx = ngx.ctx.zenskar or {}
  local session_token_entity
  local user_id_entity = nil
  local organisation_id = nil
  local request_body_entity
  local response_body_entity
  local blocked_by_entity
  local req_body_transfer_encoding = nil
  local rsp_body_transfer_encoding = nil
  local request_headers = req_get_headers()
  local response_headers = res_get_headers()
  
  if next(conf.request_header_masks) ~= nil then
    request_headers = mask_headers(req_get_headers(), conf.request_header_masks)
  end

  if next(conf.response_header_masks) ~= nil then
    response_headers = mask_headers(res_get_headers(), conf.response_header_masks)
  end

	if zenskar_ctx.req_body == nil or conf.disable_capture_request_body then
    request_body_entity = nil
  else
    local request_body_masks = mask_body_fields(conf.request_body_masks, conf.request_masks)
    request_body_entity, req_body_transfer_encoding = parse_body(request_headers, zenskar_ctx.req_body, request_body_masks, conf)
  end

	if zenskar_ctx.res_body == nil or conf.disable_capture_response_body then
    response_body_entity = nil
  else
    local response_body_masks = mask_body_fields(conf.response_body_masks, conf.response_masks)
    response_body_entity, rsp_body_transfer_encoding = parse_body(response_headers, zenskar_ctx.res_body, response_body_masks, conf)
  end

	if ngx.ctx.authenticated_credential ~= nil then
    if ngx.ctx.authenticated_credential.key ~= nil then
      session_token_entity = tostring(ngx.ctx.authenticated_credential.key)
    elseif ngx.ctx.authenticated_credential.id ~= nil then
      session_token_entity = tostring(ngx.ctx.authenticated_credential.id)
    else
      session_token_entity = nil
    end
  else
    session_token_entity = nil
  end
	ngx.log(ngx.INFO,"[zenskar] User header"..conf.user_id_header.." Request header "..request_headers[conf.user_id_header])

	if zenskar_ctx.user_id_entity == nil then 
    if conf.user_id_header ~= nil and request_headers[conf.user_id_header] ~= nil then
        zenskar_ctx.user_id_entity = tostring(request_headers[conf.user_id_header])
				ngx.log(ngx.INFO,"[zenskar] Updaint zenskar ctx with user id".. zenskar_ctx.user_id_entity)
    elseif request_headers["x-consumer-custom-id"] ~= nil then
        zenskar_ctx.user_id_entity = tostring(request_headers["x-consumer-custom-id"])
    elseif request_headers["x-consumer-username"] ~= nil then
        zenskar_ctx.user_id_entity = tostring(request_headers["x-consumer-username"])
    elseif request_headers["x-consumer-id"] ~= nil then
        zenskar_ctx.user_id_entity = tostring(request_headers["x-consumer-id"])
    elseif conf.user_id_header ~= nil and response_headers[conf.user_id_header] ~= nil then 
        zenskar_ctx.user_id_entity = tostring(response_headers[conf.user_id_header])
    end
  end

	if zenskar_ctx.customer_id_entity == nil and conf.customer_id_header ~= nil then 
    if request_headers[conf.customer_id_header] ~= nil then
        zenskar_ctx.customer_id_entity = tostring(request_headers[conf.customer_id_header])
        if conf.debug then
          ngx.log(ngx.DEBUG, "[zenskar] Customer Id from request header: " .. zenskar_ctx.customer_id_entity)
        end
    elseif response_headers[conf.customer_id_header] ~= nil then 
        zenskar_ctx.customer_id_entity = tostring(response_headers[conf.customer_id_header])
        if conf.debug then
          ngx.log(ngx.DEBUG, "[zenskar] Customer Id from response header: " .. zenskar_ctx.customer_id_entity)
        end
    end
  end
	ngx.log(ngx.INFO,"[zenskar] Serialized "..zenskar_ctx.user_id_entity)
	return {
    request = {
      uri =  helpers.prepare_request_uri(ngx, conf),
      headers = request_headers,
      body = request_body_entity,
      verb = req_get_method(),
      ip_address = client_ip.get_client_ip(request_headers),
      time = os.date("!%Y-%m-%d %H:%M:%S", req_start_time()),
      transfer_encoding = req_body_transfer_encoding,
    },
    response = {
      time = os.date("!%Y-%m-%d %H:%M:%S", ngx_now()),
      status = ngx.status,
      ip_address = Nil,
      headers = response_headers,
      body = response_body_entity,
      transfer_encoding = rsp_body_transfer_encoding,
    },
    session_token = session_token_entity,
    user_id = zenskar_ctx.user_id_entity,
    customer_id = zenskar_ctx.customer_id_entity,
    direction = "Incoming",
  }


end
return _M