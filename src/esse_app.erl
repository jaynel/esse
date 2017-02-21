%%%------------------------------------------------------------------------------
%%% @copyright (c) 2016-2017, DuoMark International, Inc.
%%% @author Jay Nelson <jay@duomark.com>
%%% @reference The license is based on the template for Modified BSD from
%%%   <a href="http://opensource.org/licenses/BSD-3-Clause">OSI</a>
%%% @doc
%%%   ESSE is the Essential Erlang Server for Sent Events.
%%%
%%%   It was consciously written to be used only on VMs running
%%%   Erlang 19.0 or later, so it uses the new map interface
%%%   for supervisor specification, and can take advantage of
%%%   any of the new optimizations.
%%%
%%% @since v0.1.0
%%% @end
%%%------------------------------------------------------------------------------
-module(esse_app).
-author('Jay Nelson <jay@duomark.com>').

-copyright("(c) 2016-2017, DuoMark International, Inc.  All rights reserved").
-author('Jay Nelson <jay@duomark.com>').
-license('New BSD').

-behaviour(application).

%% Application callbacks
-export([start/0, start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

-type restart_type() :: 'permanent' | 'transient' | 'temporary'.

-spec start()                                         ->  ok | {error, any()}.
-spec start(application:start_type(), restart_type()) -> {ok, pid()}.
-spec stop([])                                        ->  ok.

start ()             -> application:start(esse).
start (_Type, _Args) -> esse_sup:start_link().
stop  (_State)       -> ok.
