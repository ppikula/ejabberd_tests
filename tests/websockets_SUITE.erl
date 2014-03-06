%%==============================================================================
%% Copyright 2012 Erlang Solutions Ltd.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%==============================================================================

-module(websockets_SUITE).
-compile(export_all).

-include_lib("exml/include/exml.hrl").
-include_lib("escalus/include/escalus.hrl").
-include_lib("common_test/include/ct.hrl").

%%--------------------------------------------------------------------
%% Suite configuration
%%--------------------------------------------------------------------

-define(REGISTRATION_TIMEOUT, 2).  %% seconds
-define(NS_FRAMING, <<"urn:ietf:params:xml:ns:xmpp-framing">>).
-define(NS_STREAM, <<"http://etherx.jabber.org/streams">>).

all() ->
    [{group, ws_chat},
     {group, ws_protocol}].

groups() ->
    [{ws_chat, [sequence], [chat_msg]},
     {ws_protocol, [sequence], [stream_format, invalid_stream]}].

suite() ->
    escalus:suite().

%%--------------------------------------------------------------------
%% Init & teardown
%%--------------------------------------------------------------------

init_per_suite(Config) ->
    escalus:init_per_suite(Config).

end_per_suite(Config) ->
    escalus:end_per_suite(Config).

init_per_group(_GroupName, Config) ->
    escalus:create_users(Config).

end_per_group(_GroupName, Config) ->
    escalus:delete_users(Config).

init_per_testcase(CaseName, Config) ->
    escalus:init_per_testcase(CaseName, Config).

end_per_testcase(CaseName, Config) ->
    escalus:end_per_testcase(CaseName, Config).

%%--------------------------------------------------------------------
%% Message tests
%%--------------------------------------------------------------------

chat_msg(Config) ->
    escalus:story(Config, [{alice, 1}, {geralt, 1}], fun(Alice, Geralt) ->

        escalus_client:send(Alice, escalus_stanza:chat_to(Geralt, <<"Hi!">>)),
        S = escalus_client:wait_for_stanza(Geralt),
        escalus:assert(is_chat_message, [<<"Hi!">>], S),
        escalus:assert(has_ns, [<<"jabber:client">>], S),

        escalus_client:send(Geralt, escalus_stanza:chat_to(Alice, <<"Hello!">>)),
        escalus:assert(is_chat_message, [<<"Hello!">>], escalus_client:wait_for_stanza(Alice))

        end).

%%--------------------------------------------------------------------
%% New stream format
%%--------------------------------------------------------------------

stream_format(Config) ->
    GeraltSpec = escalus_users:get_options(Config, geralt),
    Host = proplists:get_value(host, GeraltSpec, <<"localhost">>),
    {ok, Conn, _NewSpec} = escalus_connection:connect(GeraltSpec),
    ok = escalus_connection:send(Conn, escalus_stanza:ws_stream_start(Host)),

    StreamStart = escalus_connection:get_stanza(Conn, wait_for_open),
    escalus_new_assert:assert(fun is_stream_start/1,StreamStart),
    
    Features = escalus_connection:get_stanza(Conn, wait_for_features),
    escalus_new_assert:assert(fun is_stream_features_stanza/1,Features),

    ok = escalus_connection:send(Conn, escalus_stanza:ws_stream_end()),
    Close = escalus_connection:get_stanza(Conn, wait_for_close),
    escalus_new_assert:assert(fun is_stream_end/1, Close),

    escalus_connection:stop(Conn),
    ok.

invalid_stream(Config) ->
    GeraltSpec = escalus_users:get_options(Config, geralt),
    {ok, Conn, _NewSpec} = escalus_connection:connect(GeraltSpec),

    ok = escalus_connection:send(Conn, #xmlel{name="someinvalidtag"}),
    Stanza = escalus_connection:get_stanza(Conn, wait_for_streamerror),
    % check error format  - should be <error> instad of <stream:error>
    escalus_new_assert:assert(fun is_error/1, Stanza),

    Close = escalus_connection:get_stanza(Conn, wait_for_close),
    escalus_new_assert:assert(fun is_stream_end/1, Close),

    escalus_connection:stop(Conn),
    ok.


%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------
is_error(#xmlel{name = <<"error">>} = Stanza)->
    escalus_pred:has_ns(?NS_STREAM, Stanza);
is_error(_)->
    false.

is_stream_end(#xmlel{name = <<"close">>} = Stanza) ->
    escalus_pred:has_ns(?NS_FRAMING, Stanza);
is_stream_end(_) ->
    false.

is_stream_start(#xmlel{name = <<"open">>} = Stanza) ->
    escalus_pred:has_ns(?NS_FRAMING, Stanza);
is_stream_start(_) ->
    false.

is_stream_features_stanza(#xmlel{name = <<"features">>} = Stanza) -> 
    escalus_pred:has_ns(?NS_STREAM,Stanza);
is_stream_features_stanza(_) ->
    false.

