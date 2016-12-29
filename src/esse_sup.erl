%%%------------------------------------------------------------------------------
%%% @copyright (c) 2016-2017, DuoMark International, Inc.
%%% @author Jay Nelson <jay@duomark.com>
%%% @reference The license is based on the template for Modified BSD from
%%%   <a href="http://opensource.org/licenses/BSD-3-Clause">OSI</a>
%%% @doc
%%%   Main supervisor controls the SSE process connection cxy_fount.
%%%
%%% @since v0.1.0
%%% @end
%%%------------------------------------------------------------------------------
-module(esse_sup).
-author('Jay Nelson <jay@duomark.com>').

-behaviour(supervisor).

%%% External API
-export([start_link/0]).

%%% Internal API
-export([init/1]).


%%%===================================================================
%%% API functions
%%%===================================================================
-spec start_link() -> supervisor:startchild_ret().

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, {}).


%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================
-spec init({}) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init({}) ->
    Fount_Options = [{slab_size, 5}, {reservoir_depth, 3}],
    FMF_Args = {cxy_fount_sup,     start_link, [esse_fount, [{}], Fount_Options ]},
    LMF_Args = {esse_listener_sup, start_link, [9997, 2]},
    Sse_Fount_Sup    = supervisor_child(esse_fount_sup,    FMF_Args),
    Sse_Listener_Sup = supervisor_child(esse_listener_sup, LMF_Args),

    Children = [
                Sse_Fount_Sup,
                Sse_Listener_Sup
               ],
    {ok, { rest_for_one_sup_options(1,5), Children} }.

rest_for_one_sup_options(Intensity, Period) ->
   #{
      strategy  => rest_for_one,
      intensity => Intensity,     % Num failures allowed,
      period    => Period         % Within this many seconds
    }.

supervisor_child(Id, {_M, _F, _A} = Start) ->
    #{
       id    => Id,
       start => Start,
       type  => supervisor
     }.
