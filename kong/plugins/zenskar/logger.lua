local _M = {}
local cjson = require "cjson"
local ngx_timer_every = ngx.timer.every
local timer_wakeup_seconds = 1.5
local http = require("ssl.https")
local ltn12 = require"ltn12"


local function send_event(message, hash_key, conf)
  local body = {
    user_id = message["user_id"],
    customer_id = message["customer_id"],
    uri = message["request"]["uri"],
    verb = message["request"]["verb"],
    status = message["response"]["status"],
    user_ip = message["request"]["ip"],
    request_headers = cjson.encode(message["request"]["headers"]),
    response_headers = cjson.encode(message["response"]["headers"]),
    response_body = cjson.encode(message["response"]["body"]),
    request_body = cjson.encode(message["request"]["body"]),
    timestamp = message["request"]["time"]
  }
  local result = {}
  ngx.log(ngx.INFO, "[zenskar] shipping logs to zenskar")
  local res, code, headers, status = http.request {
    method = "POST",
    url = conf.api_endpoint,
    source = ltn12.source.string(cjson.encode(body)),
    headers = {
         ["Content-Type"] = "application/json",
        ["Content-Length"] = string.len(cjson.encode(body)),
        ["organisation"] = conf.organisation_id,
        ["authorization"] = conf.authorization_key
    },
    sink = ltn12.sink.table(result)
  }
  ngx.log(ngx.INFO, "[zenskar] Log response status "..status)
  local response = table.concat(result)
  ngx.log(ngx.INFO,"[zenskar] log response ".. cjson.encode(response))
end

local function log(message, hash_key, conf)
  ngx.log(ngx.INFO, "[zenskar] Message final log ".. cjson.encode(message))
  ngx.log(ngx.INFO, "[zenskar] TEST".. cjson.encode(message["response"]["headers"]))
  send_event(message, hash_key, conf)
  local customer_id = message["customer_id"]
  local user_id = message["user_id"]
  local request_uri = message["request_uri"]
end


function _M.execute(conf, message)
  -- Hash key of the config application Id
  local hash_key = conf.organisation_id
  log(message, hash_key, conf)
  end

function _M.start_background_thread()

  ngx.log(ngx.INFO, "[zenskar] Scheduling Events batch job every ".. tostring(timer_wakeup_seconds).." seconds")

  local ok, err = ngx_timer_every(timer_wakeup_seconds, send_events_batch)
  if not ok then
      ngx.log(ngx.ERR, "[zenskar] Error when scheduling the job: "..err)
  end
end

return _M
