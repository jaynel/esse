%%%------------------------------------------------------------------------------
%%% @copyright (c) 2016-2017, DuoMark International, Inc.
%%% @author Jay Nelson <jay@duomark.com>
%%% @reference The license is based on the template for Modified BSD from
%%%   <a href="http://opensource.org/licenses/BSD-3-Clause">OSI</a>
%%% @doc
%%%   Simple_one_for_one supervisor which is used merely as a single
%%%   link point to take down all active Client SSE Sessions. The
%%%   number of active sessions is controlled using cxy_ctl inside
%%%   the start_child call. All children are temporary so they won't
%%%   restart, because a new client request is required to start a
%%%   replacement session (and that is handled by esse_listener using
%%%   an acceptor on the Listen Socket).
%%%
%%% @since v0.2.0
%%% @end
%%%------------------------------------------------------------------------------
-module(esse_session_sup).
-author('Jay Nelson <jay@duomark.com>').

-behaviour(supervisor).

%%% External API
-export([start_link/0, start_child/1, terminate_child/1]).

%%% Internal API
-export([init/1]).


%%%===================================================================
%%% API functions
%%%===================================================================

-type child_failure() :: negative_active_sessions | server_busy.

-spec start_link()           ->  supervisor:startchild_ret().
-spec start_child(pid())     -> {ok, pid()} | {error, child_failure()}.
-spec terminate_child(pid()) ->  ok.

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, {}).
    
start_child(Listener) ->
    Max_Sessions     = esse_env:get_max_sessions()+1,
    Incr_Sessions_Op = {3, 1, Max_Sessions-1, Max_Sessions},
    Active_Sessions  = ets:update_counter(esse_sessions, active_sessions, Incr_Sessions_Op),
    case Active_Sessions of
        N when N < 0   -> {error, negative_active_sessions};
        Max_Sessions   -> {error, server_busy};
        _Less_Than_Max -> launch_child(Listener)
    end.

launch_child(Listener) ->
    case supervisor:start_child(?MODULE, []) of
        {error, _Reason}  = Err       -> Err;
        {ok, Session_Pid} = Sup_Reply -> Listener ! {?MODULE, Session_Pid},
                                         Sup_Reply
    end.

terminate_child(Pid) ->
    supervisor:terminate_child(?MODULE, Pid).


%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

-spec init({}) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.

init({}) ->
    Session_Stream = worker_child(esse_session, start_link, []),
    {ok, {simple_one_for_one_sup_options(5,1), [Session_Stream]} }.

simple_one_for_one_sup_options(Intensity, Period) ->
   #{
      strategy  => simple_one_for_one,
      intensity => Intensity,     % Num failures allowed,
      period    => Period         % Within this many seconds
    }.

worker_child(Mod, Fun, Args) ->
    #{
       id      =>  Mod,
       start   => {Mod, Fun, Args},
       restart =>  temporary,
       type    =>  worker,
       modules => [Mod]
     }.
