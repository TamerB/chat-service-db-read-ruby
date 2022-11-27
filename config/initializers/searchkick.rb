Searchkick.client = Elasticsearch::Client.new(
    hosts:             ["http://localhost"],
    retry_on_failure:  true,
    transport_options: {
        request: {
            timeout: 450
        }
    }
)