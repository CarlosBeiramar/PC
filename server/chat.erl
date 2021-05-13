-module(chat).
-import(manager, [starter/0, login/2]).
-export([start/1, stop/1]).

start(Port) -> spawn(fun() -> server(Port) end).
stop(Server) -> Server ! stop.

room(Pids) ->
   receive
      {enter, Pid} -> 
         io:format("user_entered\n",[]),
         room([Pid | Pids]);

      {line, Data} = Msg -> 
         Info = string:split(Data, ",",all),
         io:format("received: ~s~n",[Info]),
         
         case lists:nth(1,Info) of 
               <<"login">> -> io:format("Entrou no login ~n");
               <<"logout">> -> io:format("Entrou no logout ~n")
         end,
         
         [Pid ! Msg || Pid <- Pids],
         room(Pids);
      {leave, Pid} ->
         io:format("user_left~n", []),
         room(Pids -- [Pid])
   end.

user(Sock, Room) ->
   receive
      {line, Data} ->
         gen_tcp:send(Sock, Data),
         user(Sock, Room);
      {tcp, _, Data} -> 
         Room ! {line, Data},
         user(Sock, Room);
      {tcp_closed, _} ->
         Room ! {leave, self()};
      {tcp_erro, _, _} ->
         Room ! {leave, self()}
   end.

server(Port)->
   {ok, LSock} = gen_tcp:listen(Port, [binary, {packet, line}, {reuseaddr, true}]),
   Room = spawn(fun() -> room([]) end),
   spawn(fun() -> acceptor(LSock, Room) end),
   receive stop -> ok end.

acceptor(LSock, Room) ->
    {ok, Sock} = gen_tcp:accept(LSock),
    spawn(fun() -> acceptor(LSock, Room) end),
    Room ! {enter, self()},
    user(Sock, Room).
