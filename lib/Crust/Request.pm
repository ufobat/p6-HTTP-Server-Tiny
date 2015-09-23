use v6;

unit class Crust::Request;

use URI::Escape;
use Hash::MultiValue;
use Crust::Headers;

has Hash $.env;
has Crust::Headers $headers;

method new(Hash $env) {
    self.bless(env => $env);
}

method address()      { $.env<REMOTE_ADDR> }
method remote-host()  { $.env<REMOTE_HOST> }
method protocol()     { $.env<SERVER_PROTOCOL> }
method method()       { $.env<REQUEST_METHOD> }
method port()         { $.env<SERVER_PORT> }
method user()         { $.env<REMOTE_USER> }
method request_-ri()  { $.env<REQUEST_URI> }
method path-info()    { $.env<PATH_INFO> }
method path()         { $.env<PATH_INFO> || '/' }
method query-string() { $.env<QUERY_STRING> }
method script-name()  { $.env<SCRIPT_NAME> }
method scheme()       { $.env<psgi.url_scheme> }
method secure()       { $.scheme eq 'https' }
method body()         { $.env<psgi.input> }
method input()        { $.env<psgi.input> }

method content-length()   { $.env<CONTENT_LENGTH> }
method content-type()     { $.env<CONTENT_TYPE> }

method session()         { $.env<psgix.session> }
method session-options() { $.env<psgix.session.options> }
method logger()          { $.env<psgix.logger> }

method query-parameters() {
    my Str $query_string = $.env<QUERY_STRING>;
    my @pairs = $query_string.defined
        ?? parse-uri-query($query_string)
        !! ();
    return Hash::MultiValue.from-pairs(|@pairs);
}

my sub parse-uri-query(Str $query_string is copy) {
    $query_string = $query_string.subst(/^<[&;]>+/, '');
    $query_string.split(/<[&;]>+/).map({
        if $_ ~~ /\=/ {
            my ($k, $v) = @($_.split(/\=/, 2));
            uri_unescape($k) => uri_unescape($v);
        } else {
            $_ => ''
        }
    }) ==> my @pairs;
    return @pairs;
}

method headers() {
    unless $!headers.defined {
        $!env.keys ==> grep {
            m:i/^(HTTP|CONTENT)/
        } ==> map {
            my $field = $_.subst(/^HTTPS?_/, '').subst(/_/, '-', :g);
            $field => $!env{$_}
        } ==> my %src;
        $!headers = Crust::Headers.new(%src);
    }
    return $!headers;
}

method header(Str $name) {
    $!headers.header($name);
}

method content() {
    # TODO: we should support buffering in Crust layer
    my $input = $!env<psgi.input>;
    $input.seek(0,0); # rewind
    my $content = $input.slurp-rest();
    return $content;
}

method user-agent() { self.headers.user-agent }

method content-encoding() { self.headers.content-encoding }

method referer() { self.headers.referer }

# TODO: multipart/form-data
method body-parameters() {
    $!env<crust.request.body> //= do {
        given (self.content-type) {
            when m:i/^'application/x-www-form-urlencoded' ($|\;)/ {
                my @q = parse-uri-query(self.content);
                Hash::MultiValue.from-pairs(@q);
            }
            when m:i/^'multipart/form-data' ($|\;) .*? boundary=\"?(<[^\";]>+)\"? / {
                my $boundary = $/[0];
                parse-multipart-form-data($boundary, $.env<psgi.input>);
            }
            default {
                Hash::MultiValue.new
            }
        }
    }
}

sub parse-multipart-form-data($boundary, $input) {
    my $parser = HTTP::Body::Multipart.new();
}

method parameters() {
    $!env<crust.request.merged> //= do {
        my Hash::MultiValue $q = self.query-parameters();
        my Hash::MultiValue $b = self.body-parameters();

        my @pairs = |$q.all-pairs;
        @pairs.push(|$b.all-pairs);
        Hash::MultiValue.from-pairs(|@pairs);
    };
}

method base() {
    self!uri_base;
}

method !uri_base() {
    return ($!env<psgi.url_scheme> || "http") ~
        "://" ~
        ($!env<HTTP_HOST> || (($!env<SERVER_NAME> || "") ~ ":" ~ ($!env<SERVER_PORT> || 80))) ~
        ($!env<SCRIPT_NAME> || '/');
}

# TODO: sub cookies {
# TODO: sub content {
# TODO: sub raw_body { $_[0]->content }
# TODO: sub uploads {
# TODO: sub param {
# TODO: sub upload {
# TODO: sub uri {
# TODO: sub new_response {

