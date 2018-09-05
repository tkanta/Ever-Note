# Varnish Caching
# ------------------------------------------------------------------------------
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and http://varnish-cache.org/trac/wiki/VCLExamples for more examples.
# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;
# Default backend definition. Set this to point to your content server.
backend map_backend {
    .host = "nginx-vip";
    .port = "8880";
}
sub vcl_recv {
    # Happens before we check if we have this in cache already.
    #
    # Typically you clean up the request here, removing cookies you don't need,
    # rewriting the request, etc.
    unset req.http.cookie;
    unset req.http.cache-control;
    unset req.http.pragma;
    # Remove the ids= query argument from NBI as it's unique to the client but
    # the tiles are the same
    set req.url = regsub(req.url, "&ids=[A-Ea-e0-9]+", "");
    # Remove the v= query argument from all tiles to stop cache poisoning
    set req.url = regsub(req.url, "&v=[A-Za-z0-9\.]+", "&v=1.0");
    set req.backend_hint = map_backend;
}
sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
    # Do not allow any clients to force a cache miss, this could be used
    # to cause new content to be generated when there is already a valid cached copy
    unset beresp.http.Pragma;
    unset beresp.http.Set-Cookie;
    unset beresp.http.Cache-Control;
    unset beresp.http.expires;
    # This is useful for Overlays, where they do expire frequently
    # this buys us the specified time to fetch the new content before expiring the old
    # This reduces backend load, and dogpile effect
    set beresp.grace = 1s;
    if ( bereq.url ~ "^/tiles" ) {
        set beresp.ttl = 7200s;
        set beresp.http.cache-control = "max-age = 7200";
    } elsif ( bereq.url ~ "^/map" || bereq.url ~ "^/mt" || bereq.url ~ "^/unified" ) {
        # there is a bug in nginx where it will return 204 for a /map or /mt
        # request, this should NEVER happen
        if ( beresp.status == 204 && bereq.url ~ "^/(map|mt)" )  {
            set beresp.status = 404;
        } else {
            set beresp.ttl = 180d;
            set beresp.http.cache-control = "max-age = 15552000";
        }
    } elsif ( bereq.url ~ "^/route" || bereq.url ~ "^/ptroute") {
        if ( bereq.url ~ "^/routeselector" ) {
           set beresp.ttl = 5m;
           set beresp.http.cache-control = "max-age = 300";
       } else {
           # Used for route overlay tiles but not routselector
           set beresp.ttl = 6h;
           set beresp.http.cache-control = "max-age = 21600";
       }
    } elsif ( bereq.url ~ "^/traffic") {
        set beresp.ttl = 30s;
        set beresp.http.cache-control = "max-age = 30";
    }
    if ( beresp.status == 204 ) {
        # Help ease the load on the backends when fetching tiles that do not
        # return data
        set beresp.ttl = 14400s;
        set beresp.http.cache-control = "max-age = 14400";
    } elsif ( beresp.status >= 400) {
        # On application errors or when pages don't exist, tell clients not to
        # cache, but varnish will keep the obj in cache for a short amount of
        # time.  Reduces load if there is a nasty error
        set beresp.ttl = 2s;
        unset beresp.http.cache-control;
        unset beresp.http.expires;
    }
}
sub vcl_hash {
    hash_data(req.url);
    return (lookup);
}
sub vcl_hit {
    if (req.url ~ "^/CHECK") {
	return (synth(200, "In cache"));
    }
}
sub vcl_miss {
    if (req.url ~ "^/CHECK") {
	return (synth(404, "Not in cache"));
    }
}
