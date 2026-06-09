-module(prometheus_vm_dist_collector_tests).

-include_lib("eunit/include/eunit.hrl").

-export([collect_metrics/1]).

prometheus_dist_off_test_() ->
    {foreach, fun prometheus_eunit_common:start/0, fun prometheus_eunit_common:stop/1, [
        fun test_no_distribution/1
    ]}.

test_no_distribution(_) ->
    prometheus_registry:register_collector(prometheus_vm_dist_collector),
    Metrics = prometheus_text_format:format(),
    [
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_recv_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_recv_cnt")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_recv_max_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_recv_avg_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_recv_dvi_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_send_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_send_cnt")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_send_max_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_send_avg_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_send_pend_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_port_input_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_port_output_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_port_memory_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_port_queue_size_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_proc_memory_bytes")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_proc_heap_size_words")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_proc_min_heap_size_words")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_proc_min_bin_vheap_size_words")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_proc_stack_size_words")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_proc_total_heap_size_words")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_proc_message_queue_len")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_proc_reductions")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_proc_status")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_node_state")),
        ?_assertMatch(nomatch, re:run(Metrics, "erlang_vm_dist_node_queue_size_bytes"))
    ].

prometheus_dist_tcp_test_() ->
    {setup, fun() -> start_dist_test_peers(inet_tcp) end, fun stop_dist_test_peers/1,
        fun dist_test_cases/1}.

prometheus_dist_tls_test_() ->
    {setup, fun() -> start_dist_test_peers(inet_tls) end, fun stop_dist_test_peers/1,
        fun dist_test_cases/1}.

dist_test_cases(Context) ->
    lists:append([
        test_default_metrics(Context),
        test_all_metrics(Context),
        test_custom_metrics(Context),
        test_global_labels(Context),
        test_transport_metrics(Context)
    ]).

start_dist_test_peers(Proto) ->
    Args = code_path_args() ++ dist_args(Proto),
    Options = #{
        connection => 0,
        shutdown => close,
        args => Args
    },
    {ok, PeerA, NodeA} = peer:start_link(Options#{name => peer:random_name(dist_collector_a)}),
    {ok, PeerB, NodeB} = peer:start_link(Options#{name => peer:random_name(dist_collector_b)}),
    pong = peer:call(PeerA, net_adm, ping, [NodeB], 5000),
    pong = peer:call(PeerB, net_adm, ping, [NodeA], 5000),
    {Proto, PeerA, PeerB, NodeA, NodeB}.

stop_dist_test_peers({_Proto, PeerA, PeerB, _NodeA, _NodeB}) ->
    peer:stop(PeerB),
    peer:stop(PeerA).

dist_args(inet_tcp) ->
    ["-proto_dist", "inet_tcp"];
dist_args(inet_tls) ->
    CertFile = tls_dist_file("cert.pem"),
    KeyFile = tls_dist_file("key.pem"),
    [
        "-proto_dist",
        "inet_tls",
        "-ssl_dist_opt",
        "server_certfile",
        CertFile,
        "server_keyfile",
        KeyFile,
        "server_verify",
        "verify_none",
        "server_fail_if_no_peer_cert",
        "false",
        "client_certfile",
        CertFile,
        "client_keyfile",
        KeyFile,
        "client_verify",
        "verify_none"
    ].

tls_dist_file(Name) ->
    filename:absname(filename:join("test/data/tls_dist", Name)).

code_path_args() ->
    lists:flatmap(fun(Path) -> ["-pa", Path] end, code:get_path()).

collect_metrics(default) ->
    collect_metrics(fun() -> ok end, fun() -> ok end);
collect_metrics(all) ->
    collect_metrics(
        fun() ->
            application:set_env(
                prometheus,
                vm_dist_collector_metrics,
                [
                    recv_bytes,
                    recv_cnt,
                    recv_max_bytes,
                    recv_avg_bytes,
                    recv_dvi_bytes,
                    send_bytes,
                    send_cnt,
                    send_max_bytes,
                    send_avg_bytes,
                    send_pend_bytes,
                    port_input_bytes,
                    port_output_bytes,
                    port_memory_bytes,
                    port_queue_size_bytes,
                    proc_memory_bytes,
                    proc_heap_size_words,
                    proc_min_heap_size_words,
                    proc_min_bin_vheap_size_words,
                    proc_stack_size_words,
                    proc_total_heap_size_words,
                    proc_message_queue_len,
                    proc_reductions,
                    proc_status,
                    node_state,
                    node_queue_size_bytes
                ]
            )
        end,
        fun() -> application:unset_env(prometheus, vm_dist_collector_metrics) end
    );
collect_metrics(custom) ->
    collect_metrics(
        fun() ->
            application:set_env(prometheus, vm_dist_collector_metrics, [
                recv_cnt,
                recv_dvi_bytes,
                send_max_bytes,
                send_pend_bytes,
                port_memory_bytes,
                proc_memory_bytes,
                proc_reductions,
                proc_status,
                node_state
            ])
        end,
        fun() -> application:unset_env(prometheus, vm_dist_collector_metrics) end
    );
collect_metrics(global_labels) ->
    collect_metrics(
        fun() -> application:set_env(prometheus, global_labels, [{node, node()}]) end,
        fun() -> application:unset_env(prometheus, global_labels) end
    ).

collect_metrics(InitFun, EndFun) ->
    DefaultCollectors = prometheus_eunit_common:start(),
    try
        InitFun(),
        prometheus_registry:register_collector(prometheus_vm_dist_collector),
        prometheus_text_format:format()
    after
        EndFun(),
        prometheus_eunit_common:stop(DefaultCollectors)
    end.

-define(_assertMetric(PAT, RE, METRICS),
    ?_assertMatch(PAT, re:run(METRICS, RE, [{capture, all_but_first, list}]))
).

test_default_metrics(Context) ->
    Metrics = collect_peer_metrics(Context, default),
    assert_default_metrics(Metrics) ++
        [
            ?_assertMetric(
                {match, [V]} when V =/= "0",
                "erlang_vm_dist_recv_bytes\\{[^}]*\\}\\s+([0-9]+)",
                Metrics
            ),
            ?_assertMetric(
                {match, [V]} when V =/= "0",
                "erlang_vm_dist_recv_cnt\\{[^}]*\\}\\s+([0-9]+)",
                Metrics
            ),
            ?_assertMetric(
                {match, [V]} when V =/= "0",
                "erlang_vm_dist_recv_max_bytes\\{[^}]*\\}\\s+([0-9]+)",
                Metrics
            ),
            ?_assertMetric(
                {match, [V]} when V =/= "0",
                "erlang_vm_dist_recv_avg_bytes\\{[^}]*\\}\\s+([0-9]+)",
                Metrics
            ),
            ?_assertMetric(
                {match, [V]} when V =/= "0",
                "erlang_vm_dist_send_bytes\\{[^}]*\\}\\s+([0-9]+)",
                Metrics
            ),
            ?_assertMetric(
                {match, [V]} when V =/= "0",
                "erlang_vm_dist_send_cnt\\{[^}]*\\}\\s+([0-9]+)",
                Metrics
            ),
            ?_assertMetric(
                {match, [V]} when V =/= "0",
                "erlang_vm_dist_send_max_bytes\\{[^}]*\\}\\s+([0-9]+)",
                Metrics
            ),
            ?_assertMetric(
                {match, [V]} when V =/= "0",
                "erlang_vm_dist_send_avg_bytes\\{[^}]*\\}\\s+([0-9]+)",
                Metrics
            )
        ].

test_all_metrics(Context) ->
    Metrics = collect_peer_metrics(Context, all),
    assert_default_metrics(Metrics).

test_custom_metrics(Context) ->
    Metrics = collect_peer_metrics(Context, custom),
    [
        ?_assertMetric(nomatch, "erlang_vm_dist_recv_bytes", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_recv_cnt", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_recv_max_bytes", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_recv_avg_bytes", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_recv_dvi_bytes", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_send_bytes", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_send_cnt", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_send_max_bytes", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_send_avg_bytes", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_send_pend_bytes", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_port_input_bytes", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_port_output_bytes", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_port_memory_bytes", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_port_queue_size_bytes", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_memory_bytes", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_proc_heap_size_words", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_proc_min_heap_size_words", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_proc_min_bin_vheap_size_words", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_proc_stack_size_words", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_proc_total_heap_size_words", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_proc_message_queue_len", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_reductions", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_status", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_node_state", Metrics),
        ?_assertMetric(nomatch, "erlang_vm_dist_node_queue_size_bytes", Metrics)
    ].

test_global_labels(Context) ->
    Metrics = collect_peer_metrics(Context, global_labels),
    [
        ?_assertMetric({match, _}, "erlang_vm_dist_node_state\\{node=", Metrics)
    ].

test_transport_metrics({inet_tls, _PeerA, _PeerB, _NodeA, _NodeB} = Context) ->
    Metrics = collect_peer_metrics(Context, default),
    [
        ?_assertMetric(
            {match, _},
            "erlang_vm_dist_proc_memory_bytes\\{peer=\"[^\"]+\",type=\"dist\"\\}",
            Metrics
        ),
        ?_assertMetric(
            {match, _},
            "erlang_vm_dist_proc_memory_bytes\\{peer=\"[^\"]+\",type=\"tls_connection\"\\}",
            Metrics
        ),
        ?_assertMetric(
            {match, _},
            "erlang_vm_dist_proc_memory_bytes\\{peer=\"[^\"]+\",type=\"tls_sender\"\\}",
            Metrics
        ),
        ?_assertMetric(
            {match, _},
            "erlang_vm_dist_proc_status\\{peer=\"[^\"]+\",type=\"tls_connection\"\\}",
            Metrics
        ),
        ?_assertMetric(
            {match, _},
            "erlang_vm_dist_proc_status\\{peer=\"[^\"]+\",type=\"tls_sender\"\\}",
            Metrics
        )
    ];
test_transport_metrics({inet_tcp, _PeerA, _PeerB, _NodeA, _NodeB}) ->
    [].

collect_peer_metrics({_Proto, PeerA, _PeerB, _NodeA, _NodeB}, Kind) ->
    peer:call(PeerA, ?MODULE, collect_metrics, [Kind], 5000).

assert_default_metrics(Metrics) ->
    [
        ?_assertMetric({match, _}, "erlang_vm_dist_recv_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_recv_cnt\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_recv_max_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_recv_avg_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_recv_dvi_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_send_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_send_cnt\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_send_max_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_send_avg_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_send_pend_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_port_input_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_port_output_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_port_memory_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_port_queue_size_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_memory_bytes\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_heap_size_words\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_min_heap_size_words\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_min_bin_vheap_size_words\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_stack_size_words\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_total_heap_size_words\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_message_queue_len\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_reductions\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_proc_status\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_node_state\\{peer=", Metrics),
        ?_assertMetric({match, _}, "erlang_vm_dist_node_queue_size_bytes\\{peer=", Metrics)
    ].
