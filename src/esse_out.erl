%%%------------------------------------------------------------------------------
%%% @copyright (c) 2016-2017, DuoMark International, Inc.
%%% @author Jay Nelson <jay@duomark.com>
%%% @reference The license is based on the template for Modified BSD from
%%%   <a href="http://opensource.org/licenses/BSD-3-Clause">OSI</a>
%%% @doc
%%%   Library functions for creating events to send to user_agents.
%%%
%%% @since v0.1.0
%%% @end
%%%------------------------------------------------------------------------------
-module(esse_out).
-author('Jay Nelson <jay@duomark.com>').

%%% External API
-export([retry/1]).
-export([data_only/1, data_event/2, sequence_event/3]).
-export([response_headers/1]).

-type id      () :: binary().
-type event   () :: binary().
-type data    () :: binary() | string().
-type sse_out () :: iodata().
-type millis  () :: pos_integer().


-export_type([id/0, event/0, data/0, millis/0]).

-define(CR, 13).
-define(LF, 10).


%%%===================================================================
%%% Response headers
%%%===================================================================

-type response_type () ::  ok
                         | no_content
                         | service_unavailable
                         | {temporary, binary()}
                         | {permanent, binary()}.

-spec response_headers(response_type()) -> sse_out().

%%% Response headers are only modern HTTP/1.1 format.
response_headers(ok)                                   -> make_headers(<< "HTTP/1.1 200 OK" >>);
response_headers(no_content)                           -> make_headers(<< "HTTP/1.1 204 No Content" >>);
response_headers({temporary, URL}) when is_binary(URL) -> make_headers(<< "HTTP/1.1 307 Temporary Redirect" >>, << "Location: ", URL/binary >>);
response_headers({permanent, URL}) when is_binary(URL) -> make_headers(<< "HTTP/1.1 308 Permanent Redirect" >>, << "Location: ", URL/binary >>);
response_headers(service_unavailable)                  ->
    Retry_Time = integer_to_binary(esse_env:get_retry_frequency() * 5 div 1000),
    make_headers_close(<< "HTTP/1.1 503 Service Unavailable" >>, <<"Retry-After: ", Retry_Time/binary>>, <<>>).

make_headers(Status_Code) ->
    << Status_Code          /binary, ?CR, ?LF,
       (common_headers())   /binary, ?CR, ?LF >>.

make_headers(Status_Code, Extra) ->
    << Status_Code          /binary, ?CR, ?LF,
       Extra                /binary, ?CR, ?LF,
       (common_headers())   /binary, ?CR, ?LF >>.

%% make_headers_close(Status_Code, Body) ->
%%     << Status_Code          /binary, ?CR, ?LF,
%%        (common_headers())   /binary,
%%        "Connection: close",          ?CR, ?LF,
%%        (make_content(Body)) /binary >>.

make_headers_close(Status_Code, Extra, Body) ->
    << Status_Code          /binary, ?CR, ?LF,
       Extra                /binary, ?CR, ?LF,
       (common_headers())   /binary,
       "Connection: close",          ?CR, ?LF,
       (make_content(Body)) /binary >>.

common_headers() ->
    Date   = make_timestamp(),
    Server = << "esse/", (get_version())/binary >>,
    << "Date: ",          Date   /binary,      ?CR, ?LF,
       "Server: ",        Server /binary,      ?CR, ?LF,
       "Content-Type: ",  "text/event-stream", ?CR, ?LF,
       "Cache-Control: ", "no-store",          ?CR, ?LF,  % no-cache?
       "Access-Control-Allow-Origin:", "http://127.0.0.1:9998" >>.

get_version() ->
    list_to_binary(application:get_env(esse, version, "Dev")).

make_timestamp() ->
    list_to_binary(httpd_util:rfc1123_date()).

make_content(Body) ->
    Size = integer_to_binary(byte_size(Body)),
    << "Content-Length: ", Size/binary, ?CR, ?LF,
       ?CR, ?LF,
       Body/binary >>.


%%%===================================================================
%%% Streamed data functions
%%%===================================================================

-spec data_only      (               [data()]) -> sse_out().
-spec data_event     (      event(), [data()]) -> sse_out().
-spec sequence_event (id(), event(), [data()]) -> sse_out().
    
%%% Default event type 'message'
data_only([    ])       -> <<":", ?LF>>;
data_only([<<>>])       -> <<":", ?LF>>;
data_only([Data])       -> [make_data_only(Data), ?LF];
data_only([_|_] = Data) ->
    case [make_data_only(Line) || Line <- Data, Line =/= [], Line =/= <<>>] of
        []    -> <<":", ?LF>>;
        Lines -> [Lines, ?LF]
    end.

make_data_only(Data) when is_list   (Data) -> [<<"data: ">>, Data,        ?LF];
make_data_only(Data) when is_binary (Data) ->  <<"data: ",   Data/binary, ?LF>>.

%%% Explicit event type
data_event(Event, [])           ->   <<"event: ", Event/binary, ?LF,     "data: ", ?LF, ?LF>>;
data_event(Event, [Data])       ->  [<<"event: ", Event/binary, ?LF>>,   make_data_only(Data), ?LF];
data_event(Event, [_|_] = Data) -> [[<<"event: ", Event/binary, ?LF>> | [make_data_only(Line) || Line <- Data]], ?LF].

%%% Sequence id used for resuming event stream
sequence_event(Id, Event, [])           ->  <<"id: ", Id/binary, ?LF,    (data_event(Event, []))/binary>>;
sequence_event(Id, Event, [Data])       -> [<<"id: ", Id/binary, ?LF>> |  data_event(Event, [Data])];
sequence_event(Id, Event, [_|_] = Data) -> [<<"id: ", Id/binary, ?LF>> |  data_event(Event,  Data )].


%%%===================================================================
%%% Other stream functions
%%%===================================================================

-spec retry(millis()) -> sse_out().

retry(Millis) -> <<"retry: ", (integer_to_binary(Millis))/binary, ?LF, ?LF>>.
