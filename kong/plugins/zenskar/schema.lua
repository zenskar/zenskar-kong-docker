local typedefs = require "kong.db.schema.typedefs"

return {
  name = "zenskar",
  fields = {
    {
      consumer = typedefs.no_consumer
    },
    {
      protocols = typedefs.protocols_http
    },
    {
      config = {
        type = "record",
        fields = {
          {
            api_endpoint = { type = "string", default = "https://api.zenskar.com"}
          },
          {
            organisation_id = {required = true, default = nil, type="string"}
          },
          {
            authorization_key = {required = true, default = nill, type="string"}
          },
          {
            disable_capture_request_body = {default = false, type = "boolean"}
          },
          {
            disable_capture_response_body = {default = false, type = "boolean"}
          },
          {
            request_masks = {default = {}, type = "array", elements = typedefs.header_name}
          },
          {
            request_body_masks = {default = {}, type = "array", elements = typedefs.header_name}
          },
          {
            request_header_masks = {default = {}, type = "array", elements = typedefs.header_name}
          },
          {
            response_masks = {default = {}, type = "array", elements = typedefs.header_name}
          },
          {
            response_body_masks = {default = {}, type = "array", elements = typedefs.header_name}
          },
          {
            response_header_masks = {default = {}, type = "array", elements = typedefs.header_name}
          },
          {
            customer_id_header = {default = nil, type = "string"}
          },
          {
            user_id_header = {default = nil, type = "string"}
          },
          {
            authorization_header_name = {default = "authorization", type = "string"}
          },
          {
            authorization_user_id_field = {default = "sub", type = "string"}
          },
          {
            request_max_body_size_limit = {default = 100000, type = "number"}
          },
          {
            response_max_body_size_limit = {default = 100000, type = "number"}
          },
          {
            request_query_masks = {default = {}, type = "array", elements = typedefs.header_name}
          },
          {
            enable_reading_send_event_response = {default = false, type = "boolean"}
          },
        },
      },
    },
  },
  entity_checks = {}
}
