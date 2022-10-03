vcl 4.0;
import std;
import directors;
# Importing GeoIP module to set Country Code.
import geoip;

# This Varnish VCL has been adapted from the Four Kitchens VCL for Varnish 3.
# This VCL is for using cache tags with drupal 8. Minor chages of VCL provided by Jeff Geerling.

# Default backend definition. Points to Apache, normally.
# Apache is in this config on port 80.
backend default {
    .host = "web";
    .port = "80";
    .first_byte_timeout = 300s;
}
# Access control list for PURGE requests.
acl purge {
    "172.22.0.0/16";
}
# Respond to incoming requests.
sub vcl_recv {
    # Add an X-Forwarded-For header with the client IP address.
    if (req.restarts == 0) {
        if (req.http.X-Forwarded-For) {
            set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
        }
        else {
            set req.http.X-Forwarded-For = client.ip;
        }
    }
    # Only allow PURGE requests from IP addresses in the 'purge' ACL.
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "Not allowed."));
        }
        return (purge);
    }
    # Only allow BAN requests from IP addresses in the 'purge' ACL.
    if (req.method == "BAN") {
        # Same ACL check as above:
        if (!client.ip ~ purge) {
            return (synth(403, "Not allowed."));
        }
        # Logic for the ban, using the Cache-Tags header. For more info
        # see https://github.com/geerlingguy/drupal-vm/issues/397.
        if (req.http.Cache-Tags) {
            ban("obj.http.Cache-Tags ~ " + req.http.Cache-Tags);
        }
        else {
            return (synth(403, "Cache-Tags header missing."));
        }
        # Throw a synthetic page so the request won't go to the backend.
        return (synth(200, "Ban added."));
    }
    # Set Country-Code.
    set req.http.X-Geo-Country = geoip.country_code(client.ip);
    # Only cache GET and HEAD requests (pass through POST requests).
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }
    # Pass through any administrative or AJAX-related paths.
    if (req.url ~ "^/status\.php$" ||
        req.url ~ "^/update\.php$" ||
        req.url ~ "^/admin$" ||
        req.url ~ "^/admin/.*$" ||
        req.url ~ "^/flag/.*$" ||
        req.url ~ "^.*/ajax/.*$" ||
        req.url ~ "^.*/ahah/.*$" ||
        req.url ~ "^/user/.*$" ||
        req.url ~ "^.*/node/.*/webform/results/download") {
           return (pass);
    }
    # Removing cookies for static content so Varnish caches these files.
    if (req.url ~ "(?i)\.(pdf|asc|dat|txt|doc|xls|ppt|tgz|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
        unset req.http.Cookie;
    }
    # Remove all cookies that Drupal doesn't need to know about. We explicitly
    # list the ones that Drupal does need, the SESS and NO_CACHE. If, after
    # running this code we find that either of these two cookies remains, we
    # will pass as the page cannot be cached.
    if (req.http.Cookie) {
        # 1. Append a semi-colon to the front of the cookie string.
        # 2. Remove all spaces that appear after semi-colons.
        # 3. Match the cookies we want to keep, adding the space we removed
        #    previously back. (\1) is first matching group in the regsuball.
        # 4. Remove all other cookies, identifying them by the fact that they have
        #    no space after the preceding semi-colon.
        # 5. Remove all spaces and semi-colons from the beginning and end of the
        #    cookie string.
        set req.http.Cookie = ";" + req.http.Cookie;
        set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
        set req.http.Cookie = regsuball(req.http.Cookie, ";(SESS[a-z0-9]+|SSESS[a-z0-9]+|NO_CACHE)=", "; \1=");
        set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");
        if (req.http.Cookie == "") {
            # If there are no remaining cookies, remove the cookie header. If there
            # aren't any cookie headers, Varnish's default behavior will be to cache
            # the page.
            unset req.http.Cookie;
        }
        else {
            # If there is any cookies left (a session or NO_CACHE cookie), do not
            # cache the page. Pass it on to Apache directly.
            return (pass);
        }
    }
}
# Set a header to track a cache HITs and MISSes.
sub vcl_deliver {
    # Remove ban-lurker friendly custom headers when delivering to client.
    unset resp.http.X-Url;
    unset resp.http.X-Host;

    # Comment these for easier Drupal cache tag debugging in development.
    # unset resp.http.Cache-Tags;
    # unset resp.http.X-Drupal-Cache-Contexts;

    # Code below taken from https://www.varnish-software.com/wiki/content/tutorials/drupal/drupal_vcl.html#debugging-headers.
    # Please consider the risks of showing publicly this information, we can wrap
    # this with an ACL.
    # Add whether the object is a cache hit or miss and the number of hits for
    # the object.
    # SeeV3 https://www.varnish-cache.org/trac/wiki/VCLExampleHitMissHeader#Addingaheaderindicatinghitmiss
    # In Varnish 4 the obj.hits counter behaviour has changed (see bug 1492), so
    # we use a different method: if X-Varnish contains only 1 id, we have a miss,
    # if it contains more (and therefore a space), we have a hit.
    if ( resp.http.X-Varnish ~ " " ) {
      set resp.http.Cache-Tags = "HIT";
    } else {
      set resp.http.Cache-Tags = "MISS";
    }

    # Comment lines below after debugging.
    /* Show the results of cookie sanitization */
    if ( req.http.Cookie ) {
        set resp.http.X-Varnish-Cookie = req.http.Cookie;
    }
    # Since in Varnish 4 the behaviour of obj.hits changed, this might not be
    # accurate.
    # See https://www.varnish-cache.org/trac/ticket/1492
    set resp.http.X-Varnish-Cache-Hits = obj.hits;
}
# Instruct Varnish what to do in the case of certain backend responses (beresp).
sub vcl_backend_response {
    # Set ban-lurker friendly custom headers.
    set beresp.http.X-Url = bereq.url;
    set beresp.http.X-Host = bereq.http.host;
    # Cache 404s, 301s, at 500s with a short lifetime to protect the backend.
    if (beresp.status == 404 || beresp.status == 301 || beresp.status == 500) {
        set beresp.ttl = 10m;
    }
    # Enable streaming directly to backend for BigPipe responses.
    if (beresp.http.Surrogate-Control ~ "BigPipe/1.0") {
        set beresp.do_stream = true;
        set beresp.ttl = 0s;
    }
    # Don't allow static files to set cookies.
    # (?i) denotes case insensitive in PCRE (perl compatible regular expressions).
    # This list of extensions appears twice, once here and again in vcl_recv so
    # make sure you edit both and keep them equal.
    if (bereq.url ~ "(?i)\.(pdf|asc|dat|txt|doc|xls|ppt|tgz|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
        unset beresp.http.set-cookie;
    }
    # Allow items to remain in cache up to 6 hours past their cache expiration.
    set beresp.grace = 6h;
}
# Hash includes Country-Code as described here
# https://varnish-cache.org/docs/trunk/users-guide/vcl-hashing.html.
sub vcl_hash {
    hash_data(req.http.X-Geo-Country);
}
