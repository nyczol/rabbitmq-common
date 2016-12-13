%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_core_metrics).

-include("rabbit_core_metrics.hrl").

-export([init/0]).

-export([connection_created/2,
         connection_closed/1,
         connection_stats/2,
         connection_stats/4]).

-export([channel_created/2,
         channel_closed/1,
         channel_stats/2,
         channel_stats/3,
         channel_stats/4,
         channel_queue_down/1,
         channel_queue_exchange_down/1,
         channel_exchange_down/1]).

-export([consumer_created/7,
         consumer_deleted/3]).

-export([queue_stats/2,
         queue_stats/5,
         queue_deleted/1]).

-export([node_stats/2]).

-export([node_node_stats/2]).

%% Those functions are exported for internal use only, not for public
%% consumption.
-export([
         ets_update_counter/4,
         ets_update_counter_pre_18/4,
         ets_update_counter_post_18/4
        ]).

-erlang_version_support([
                         {18, [
                               {ets_update_counter, 4,
                                ets_update_counter_pre_18,
                                ets_update_counter_post_18}
                              ]}
                        ]).

%%----------------------------------------------------------------------------
%% Types
%%----------------------------------------------------------------------------
-type(channel_stats_id() :: pid() |
			    {pid(),
			     {rabbit_amqqueue:name(), rabbit_exchange:name()}} |
			    {pid(), rabbit_amqqueue:name()} |
			    {pid(), rabbit_exchange:name()}).

-type(channel_stats_type() :: queue_exchange_stats | queue_stats |
			      exchange_stats | reductions).
%%----------------------------------------------------------------------------
%% Specs
%%----------------------------------------------------------------------------
-spec init() -> ok.
-spec connection_created(pid(), rabbit_types:infos()) -> ok.
-spec connection_closed(pid()) -> ok.
-spec connection_stats(pid(), rabbit_types:infos()) -> ok.
-spec connection_stats(pid(), integer(), integer(), integer()) -> ok.
-spec channel_created(pid(), rabbit_types:infos()) -> ok.
-spec channel_closed(pid()) -> ok.
-spec channel_stats(pid(), rabbit_types:infos()) -> ok.
-spec channel_stats(channel_stats_type(), channel_stats_id(),
                    rabbit_types:infos() | integer()) -> ok.
-spec channel_queue_down({pid(), rabbit_amqqueue:name()}) -> ok.
-spec channel_queue_exchange_down({pid(), {rabbit_amqqueue:name(),
                                   rabbit_exchange:name()}}) -> ok.
-spec channel_exchange_down({pid(), rabbit_exchange:name()}) -> ok.
-spec consumer_created(pid(), binary(), boolean(), boolean(),
                       rabbit_amqqueue:name(), integer(), list()) -> ok.
-spec consumer_deleted(pid(), binary(), rabbit_amqqueue:name()) -> ok.
-spec queue_stats(rabbit_amqqueue:name(), rabbit_types:infos()) -> ok.
-spec queue_stats(rabbit_amqqueue:name(), integer(), integer(), integer(),
                  integer()) -> ok.
-spec node_stats(atom(), rabbit_types:infos()) -> ok.
-spec node_node_stats({node(), node()}, rabbit_types:infos()) -> ok.
%%----------------------------------------------------------------------------
%% Storage of the raw metrics in RabbitMQ core. All the processing of stats
%% is done by the management plugin.
%%----------------------------------------------------------------------------
%%----------------------------------------------------------------------------
%% API
%%----------------------------------------------------------------------------
init() ->
    [ets:new(Table, [Type, public, named_table, {write_concurrency, true}])
     || {Table, Type} <- ?CORE_TABLES],
    ok.

connection_created(Pid, Infos) ->
    ets:insert(connection_created, {Pid, Infos}),
    ok.

connection_closed(Pid) ->
    ets:delete(connection_created, Pid),
    ets:delete(connection_metrics, Pid),
    ets:delete(connection_coarse_metrics, Pid),
    ok.

connection_stats(Pid, Infos) ->
    ets:insert(connection_metrics, {Pid, Infos}),
    ok.

connection_stats(Pid, Recv_oct, Send_oct, Reductions) ->
    ets:insert(connection_coarse_metrics, {Pid, Recv_oct, Send_oct, Reductions}),
    ok.

channel_created(Pid, Infos) ->
    ets:insert(channel_created, {Pid, Infos}),
    ok.

channel_closed(Pid) ->
    ets:delete(channel_created, Pid),
    ets:delete(channel_metrics, Pid),
    ets:delete(channel_process_metrics, Pid),
    ok.

channel_stats(Pid, Infos) ->
    ets:insert(channel_metrics, {Pid, Infos}),
    ok.

channel_stats(reductions, Id, Value) ->
    ets:insert(channel_process_metrics, {Id, Value}),
    ok.

channel_stats(exchange_stats, publish, Id, Value) ->
    ets_update_counter(channel_exchange_metrics, Id, {2, Value}, {Id, 0, 0, 0}),
    ok;
channel_stats(exchange_stats, confirm, Id, Value) ->
    ets_update_counter(channel_exchange_metrics, Id, {3, Value}, {Id, 0, 0, 0}),
    ok;
channel_stats(exchange_stats, return_unroutable, Id, Value) ->
    ets_update_counter(channel_exchange_metrics, Id, {4, Value}, {Id, 0, 0, 0}),
    ok;
channel_stats(queue_exchange_stats, publish, Id, Value) ->
    ets_update_counter(channel_queue_exchange_metrics, Id, Value, {Id, 0}),
    ok;
channel_stats(queue_stats, get, Id, Value) ->
    ets_update_counter(channel_queue_metrics, Id, {2, Value}, {Id, 0, 0, 0, 0, 0, 0}),
    ok;
channel_stats(queue_stats, get_no_ack, Id, Value) ->
    ets_update_counter(channel_queue_metrics, Id, {3, Value}, {Id, 0, 0, 0, 0, 0, 0}),
    ok;
channel_stats(queue_stats, deliver, Id, Value) ->
    ets_update_counter(channel_queue_metrics, Id, {4, Value}, {Id, 0, 0, 0, 0, 0, 0}),
    ok;
channel_stats(queue_stats, deliver_no_ack, Id, Value) ->
    ets_update_counter(channel_queue_metrics, Id, {5, Value}, {Id, 0, 0, 0, 0, 0, 0}),
    ok;
channel_stats(queue_stats, redeliver, Id, Value) ->
    ets_update_counter(channel_queue_metrics, Id, {6, Value}, {Id, 0, 0, 0, 0, 0, 0}),
    ok;
channel_stats(queue_stats, ack, Id, Value) ->
    ets_update_counter(channel_queue_metrics, Id, {7, Value}, {Id, 0, 0, 0, 0, 0, 0}),
    ok.

%% ets:update_counter(Tab, Key, Incr, Default) appeared in Erlang 18.x.
%% We need a wrapper for Erlang R16B03 and Erlang 17.x.

ets_update_counter(Tab, Key, Incr, Default) ->
    code_version:update(?MODULE),
    ?MODULE:ets_update_counter(Tab, Key, Incr, Default).

ets_update_counter_pre_18(Tab, Key, Incr, Default) ->
    %% The wrapper tries to update the counter first. If it's missing
    %% (and a `badarg` is raised), it inserts the default value and
    %% tries to update the counter one more time.
    try
        ets:update_counter(Tab, Key, Incr)
    catch
        _:badarg ->
            try
                %% There is no atomicity here, so between the
                %% call to `ets:insert_new/2` and the call to
                %% `ets:update_counter/3`, the the counters have
                %% a temporary value (which is not possible with
                %% `ets:update_counter/4). Furthermore, there is a
                %% chance for the counter to be removed between those
                %% two calls as well.
                ets:insert_new(Tab, Default),
                ets:update_counter(Tab, Key, Incr)
            catch
                _:badarg ->
                    %% We can't tell with just `badarg` what the real
                    %% cause is. We have no way to decide if we should
                    %% try to insert/update the counter again, so let's
                    %% do nothing.
                    0
            end
    end.

ets_update_counter_post_18(Tab, Key, Incr, Default) ->
    ets:update_counter(Tab, Key, Incr, Default).

channel_queue_down(Id) ->
    ets:delete(channel_queue_metrics, Id),
    ok.

channel_queue_exchange_down(Id) ->
    ets:delete(channel_queue_exchange_metrics, Id),
    ok.

channel_exchange_down(Id) ->
    ets:delete(channel_exchange_metrics, Id),
    ok.

consumer_created(ChPid, ConsumerTag, ExclusiveConsume, AckRequired, QName,
                 PrefetchCount, Args) ->
    ets:insert(consumer_created, {{QName, ChPid, ConsumerTag}, ExclusiveConsume,
                                   AckRequired, PrefetchCount, Args}),
    ok.

consumer_deleted(ChPid, ConsumerTag, QName) ->
    ets:delete(consumer_created, {QName, ChPid, ConsumerTag}),
    ok.

queue_stats(Name, Infos) ->
    ets:insert(queue_metrics, {Name, Infos}),
    ok.

queue_stats(Name, MessagesReady, MessagesUnacknowledge, Messages, Reductions) ->
    ets:insert(queue_coarse_metrics, {Name, MessagesReady, MessagesUnacknowledge,
                                      Messages, Reductions}),
    ok.

queue_deleted(Name) ->
    ets:delete(queue_metrics, Name),
    ets:delete(queue_coarse_metrics, Name),
    ets:select_delete(channel_queue_exchange_metrics, match_spec_cqx(Name)),
    ets:select_delete(channel_queue_metrics, match_spec_cq(Name)).

node_stats(persister_metrics, Infos) ->
    ets:insert(node_persister_metrics, {node(), Infos});
node_stats(coarse_metrics, Infos) ->
    ets:insert(node_coarse_metrics, {node(), Infos});
node_stats(node_metrics, Infos) ->
    ets:insert(node_metrics, {node(), Infos}).

node_node_stats(Id, Infos) ->
    ets:insert(node_node_metrics, {Id, Infos}).

match_spec_cqx(Id) ->
    [{{{'_', {'$1', '_'}}, '_'}, [{'==', {Id}, '$1'}], [true]}].

match_spec_cq(Id) ->
    [{{{'_', '$1'}, '_', '_', '_', '_', '_', '_'}, [{'==', {Id}, '$1'}], [true]}].