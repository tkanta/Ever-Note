vcl 4.0;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "10.10.13.17";
    .port = "5000";
#    .connect_timeout=10s;
#    .between_bytes_timeout = 30s;
}

sub vcl_recv {
    # Happens before we check if we have this in cache already.
    #
    # Typically you clean up the request here, removing cookies you don't need,
    # rewriting the request, etc.
    #
    set req.backend_hint = default;
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
    #

    unset beresp.http.Pragma;
    unset beresp.http.Set-Cookie;
    unset beresp.http.Cache-Control;
    unset beresp.http.expires;
    set beresp.grace = 1s;
    if( bereq.url ~ "tiles" ) {
        set beresp.ttl = 7200s;
        set beresp.http.cache-control = "max-age = 7200";
    }

}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object here.
}
