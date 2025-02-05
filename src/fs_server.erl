-module(fs_server).
-behaviour(gen_server).
-define(SERVER, ?MODULE).
-export([start_link/5]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,terminate/2, code_change/3]).

-record(state, {event_handler, port, path, backend}).

notify(EventHandler, file_event = A, Msg) -> Key = {fs, A}, gen_event:notify(EventHandler, {self(), Key, Msg}).
start_link(Name, EventHandler, Backend, Path, Cwd) -> gen_server:start_link({local, Name}, ?MODULE, [EventHandler, Backend, Path, Cwd], []).
init([EventHandler, Backend, Path, Cwd]) ->
    Port = Backend:start_port(Path, Cwd),
    io_lib:format("fs listening port ~p with path ~p~n", [Port, Path]),
     {ok, #state{event_handler=EventHandler, port=Port, path=Path, backend=Backend}}.

handle_call(known_events, _From, #state{backend=Backend} = State) -> {reply, Backend:known_events(), State};
handle_call(_Request, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
handle_info({_Port, {data, {eol, Line}}}, #state{event_handler=EventHandler,backend=Backend} = State) ->
    io_lib:format("fs handle_info ~p~n", [Line]),
    Event = Backend:line_to_event(Line),
    notify(EventHandler, file_event, Event),
    {noreply, State};
handle_info({_Port, {data, {noeol, Line}}}, State) ->
        io_lib:format("~p line too long: ~p, ignoring~n", [?SERVER, Line]),
    {noreply, State};
handle_info({_Port, {exit_status, Status}}, State) -> 
    io_lib:format("fs port exit ~p~n", [Status]),
    {stop, {port_exit, Status}, State};
handle_info(Info, State) ->
        io_lib:format("fs unexpected info ~p~n", [Info]),
             {noreply, State}.
terminate(_Reason, #state{port=Port}) -> (catch port_close(Port)), ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.
