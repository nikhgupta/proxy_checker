# ProxyChecker

Gem to check a proxy for its capabilities, and to fetch related information.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'proxy_checker'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install proxy_checker

## Usage

```ruby
ProxyChecker.check("123.123.123.123", "12345")
# => get information about the IP address "123.123.123.123".
# => check if the proxy supports HTTP, HTTPS, and POST capabilities.

ProxyChecker.check("123.123.123.123", "12345", info: false)
# => does not fetch information about the IP address.

ProxyChecker.check("123.123.123.123", "12345", protocols: [:http, :post])
# => check if proxy supports HTTP, and POST capabilities only.
# => fetch information about the IP address.
```

You can configure various options for the gem in `.configure` block.

### URLs to various services

`%{ip}` is replaced with the Proxy IP address, and `%{port}` with the
port of the proxy.

```ruby
ProxyChecker.configure do |config|
  # URL to check the information about the Proxy IP
  config.info_url = "http://ip-api.com/json/%{ip}"

  # URL(s) for the proxy judges being used
  # This can either be hosted yourself, or a script can be created for
  # the same.
  # Note that, if you use a custom URL here, you should setup various
  # protocol blocks.
  config.judge_urls = [ "http://www.rx2.eu/ivy/azenv.php", "http://luisaranguren.com/azenv.php" ]

  # URL to check the current IP address for the server.
  # Note that, the service must return IP as the only text.
  # Also, this is only used if the CURRENT_IP is not setup as env. var.
  config.current_ip_url = "https://api.ipify.org/?format=text"
end
```

### Timeouts, SSL and other options

```ruby
ProxyChecker.configure do |config|
  config.read_timeout = 10            # timeout for HTTP read
  config.connect_timeout = 5          # timeout for HTTP connect

  # Whether to keep HTTP requests that failed validation (based on
  # protocol blocks) in the returned results.
  config.keep_failed_attempts = false

  # SSL Context to use when making HTTPS requests.
  # By default, this is set to not verify SSL certificates.
  ssl_context = OpenSSL::SSL::SSLContext.new
  ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  config.ssl_context = ssl_context
end
```

### Logging Errors

```ruby
ProxyChecker.configure do |config|
  config.log_error = -> (e) { puts "\e[31mEncountered ERROR: #{e.class} #{e}\e[0m" }

  # This block can also accept 4 params, as below:
  config.log_error = -> (error, uri, response, time_taken) { ... some code ... }
end
```

### Protocol Blocks

In the following example, `key` refers to the protocol/capability that
is being validated, `uri` refers to the URL of the server/judge where
the request was made, `response` is the response object received from
the judge, and `time` is the time taken (in ms) for the request to
complete.

```ruby
ProxyChecker.configure do |config|
  config.http_block = -> (key, uri, response, time){
    response.code == 200 && !!response.body.match(/request_method\s+=\s+get/i)
  }

  config.https_block = -> (key, uri, response, time){
    response.code == 200 && !!response.body.match(/https\s+=\s+on.*request_method\s+=\s+get/mi)
  }

  config.post_block = -> (key, uri, response, time){
    response.code == 200 && !!response.body.match(/request_method\s+=\s+post/i)
  }
end
```

### Website blocks

```ruby
ProxyChecker.configure do |config|
  config.websites = {
    google:    "http://www.google.com/search?q=%{s}",
    twitter:   "http://twitter.com/search?q=%{s}",
    youtube:   "http://www.youtube.com/results?search_query=%{s}",
    facebook:  "http://www.facebook.com/search/top/?q=%{s}",
    pinterest: "http://www.pinterest.com/search/?q=%{s}",
  }

end
```

You can read config values for the gem:

```ruby
ProxyChecker.config.info_url
# => "http://ip-api.com/json/%{ip}"
ProxyChecker.config.current_ip
# => "123.123.123.123"
ProxyChecker.config.timeout
# => { read_timeout: 10, connect_timeout: 5, write_timeout: 10 }
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/proxy_checker.

