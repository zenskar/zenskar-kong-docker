## Kong with Zenskar

Example Docker application for using [Kong Plugin](https://github.com/zenskar/kong-plugin) to log API analytics to [Zenskar](https://app.zenskar.com)

To learn more about configuration options, please refer to [Kong Plugin](https://github.com/zenskar/kong-plugin)

## Run
1. Start the docker container:
```bash
docker-compose -f docker-compose.yml up -d
```

2. Configure the Zenskar plugin
```bash
curl --location 'http://localhost:8001/plugins' \
--data-urlencode 'name=zenskar' \
--data-urlencode 'config.api_endpoint=https://api.zenskar.com/usage/<raw_metric_slug>' \
--data-urlencode 'config.organisation_id=<organisation_id>' \
--data-urlencode 'config.customer_id_header=<customer_header>' \
--data-urlencode 'config.user_id_header=<user_id>' \
--data-urlencode 'config.authorization_key=<zenskar_token>'
```

Your Zenskar authorization_key and organisation_id can be found in the [Zenskar Portal](https://app.zenskar.com/).
customer_id and user_id headers are how you identify a customer and the user who called the api. 


3. Create a service

```bash
curl -i -X POST \
  --url http://localhost:8001/services/ \
  --data 'name=example-zenskar-service' \
  --data 'url=http://httpbin.org/uuid'
```

4. Create a route

```bash
curl -i -X POST \
  --url http://localhost:8001/services/example-zenskar-service/routes \
  --data 'hosts[]=test.com'
```

5. By default, The container is listening on port 80. You should now be able to make a request: 

```bash
curl --location 'http://localhost:80/' \
--header 'Host: test.com' \
--header 'api_key: 8504c7eb-156c-4ea2-9512-a5ffe31dd47b' \
--header 'user_id: axis_bank'
```

6. The data should be captured in the corresponding Zenskar Account [Raw Metrics](https://app.zenskar.com/meters/raw-metrics/).

Congratulations! If everything was done correctly, Zenskar should now be tracking all network requests that match the route you specified earlier. If you have any issues with the setup, please reach out to support@zenskar.com.

