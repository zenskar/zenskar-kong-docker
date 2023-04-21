local ZenskarLogHandler = {
  VERSION  = "1.0.0",
  PRIORITY = 5,
}

local logger = require "kong.plugins.zenskar.logger"
local req_set_header = ngx.req.req_set_header
local req_set_header = ngx.req.set_header
local string_find = string.find
local req_read_body = ngx.req.read_body
local req_get_headers = ngx.req.get_headers
local req_get_body_data = ngx.req.get_body_data
local socket = require "socket"
local serializer = require "kong.plugins.zenskar.serializer"

queue_hashes = {}

-- https://gist.github.com/jrus/3197011#file-lua-uuid-lua
local function uuid()	
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'	
    return string.gsub(template, '[xy]', function (c)	
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)	
        return string.format('%x', v)	
    end)	
end

function ZenskarLogHandler:access(conf)
    
    local start_access_phase_time = socket.gettime()*1000
    ngx.log(ngx.INFO, "[zenskar] Access Phase started")
    local headers = req_get_headers()

    if headers["X-Zenskar-Transaction-Id"] ~= nil then	
      local req_trans_id = headers["X-Zenskar-Transaction-Id"]	
      if req_trans_id ~= nil and req_trans_id:gsub("%s+", "") ~= "" then	
        ngx.ctx.transaction_id = req_trans_id	
      else	
        ngx.ctx.transaction_id = uuid()	
      end	
    else	
      ngx.ctx.transaction_id = uuid()	
    end	

    req_set_header("X-Zenskar-Transaction-Id", ngx.ctx.transaction_id)	

    local req_body, res_body = "", ""
    local req_post_args = {}
    local err = nil
    local mimetype = nil
    local content_length = headers["content-length"]

    -- Hash key of the config application Id
    local hash_key = conf.organisation_id

    req_read_body()
    local read_request_body = req_get_body_data()
    
    if content_length == nil and read_request_body ~= nil then
        req_body = read_request_body
        local content_type = headers["content-type"]
        if content_type and string_find(content_type:lower(), "application/x-www-form-urlencoded", nil, true) then
            req_post_args, err, mimetype = kong.request.get_body()
        end
    end

    ngx.ctx.zenskar = {
        req_body = req_body,
        res_body = res_body,
        req_post_args = req_post_args
  }
  local end_access_phase_time = socket.gettime()*1000
  ngx.log(ngx.INFO, "[zenskar] access phase took time for non-blocking request - ".. tostring(end_access_phase_time - start_access_phase_time).." for pid - ".. ngx.worker.pid())
end

function ZenskarLogHandler:body_filter(conf)
    local start_access_phase_time = socket.gettime()*1000
    ngx.log(ngx.INFO, "[zenskar] body filter Phase called for the new event" .. " for pid" .. ngx.worker.pid())
    local headers = ngx.resp.get_headers()
    local content_length = headers["content-length"]

    -- Hash key of the config application Id
    local hash_key = conf.organisation_id

    if content_length == nil then
        local chunk = ngx.arg[1]
        local zenskar_data = ngx.ctx.zenskar or {res_body = ""}
        zenskar_data.res_body = zenskar_data.res_body .. chunk
        ngx.ctx.zenskar = zenskar_data
    end
    local end_access_phase_time = socket.gettime()*1000
    ngx.log(ngx.INFO, "[zenskar] body filter phase took time for non-blocking request - ".. tostring(end_access_phase_time - start_access_phase_time).." for pid - ".. ngx.worker.pid())
 end

function ensure_body_size_under_limit(ngx, conf)
  local zenskar_ctx = ngx.ctx.zenskar or {}

  if zenskar_ctx.res_body ~= nil and (string.len(zenskar_ctx.res_body) >= conf.response_max_body_size_limit) then
    zenskar_ctx.res_body = nil
  end
end

function log_event(ngx, conf)
  local start_log_phase_time = socket.gettime()*1000
  ensure_body_size_under_limit(ngx, conf)
  local message = serializer.serialize(ngx, conf)
  logger.execute(conf, message)
  local end_log_phase_time = socket.gettime()*1000
  ngx.log(ngx.DEBUG, "[zenskar] log phase took time - ".. tostring(end_log_phase_time - start_log_phase_time).." for pid - ".. ngx.worker.pid())
end


function ZenskarLogHandler:log(conf)
  ngx.log(ngx.DEBUG, '[zenskar] Log phase called for the new event ' .." for pid - ".. ngx.worker.pid())

  -- Hash key of the config application Id
  local hash_key = conf.organisation_id
  if (queue_hashes[hash_key] == nil) or 
        (queue_hashes[hash_key] ~= nil and type(queue_hashes[hash_key]) == "table") then
      if (queue_hashes[hash_key] ~= nil and type(queue_hashes[hash_key]) == "table") then 
        ngx.log(ngx.DEBUG, '[zenskar] logging new event where the current number of events in the queue is '.. tostring(#queue_hashes[hash_key]) .. " for pid - ".. ngx.worker.pid())
      else 
        ngx.log(ngx.DEBUG, '[zenskar] logging new event when queue hash is nil ' .." for pid - ".. ngx.worker.pid())
      end
    log_event(ngx, conf)
  end
end

-- function ZenskarLogHandler:init_worker()
--   ngx.log(ngx.DEBUG, '[zenskar] Init Worker Executed')
--   logger.start_background_thread()
-- end

plugin_version = ZenskarLogHandler.VERSION

return ZenskarLogHandler