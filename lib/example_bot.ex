defmodule MAX.ExampleBot do
  use MAX.Bot

  def handle_update(%{"update_type" => "message_created", "message" => %{"sender" => sender, "body" => %{"text" => "wait"}}}, bot_state) do
    post("/messages", %{text: "Im waiting 2 minutes"}, user_id: sender["user_id"])
    {:ok, bot_state, 120}
  end
  
  def handle_update(%{"update_type" => "message_created", "message" => %{"sender" => _sender, "body" => %{"text" => "raise"}}}, _bot_state) do
    raise("Runtime error catched and rescued.")
  end
  
  def handle_update(%{"update_type" => "message_created", "message" => %{"sender" => sender, "body" => %{"text" => _text}}}, bot_state) do
    bot_state = if not is_integer(bot_state), do: 1, else: bot_state+1
    # this function just count messages during the session
    username = sender["first_name"]
    post("/messages", %{text: "Hello, #{username}. You messaged #{bot_state} times."}, user_id: sender["user_id"])
    {:ok, bot_state}
  end

  def handle_update(_update, bot_state) do
    {:ok, bot_state} # just return bot_state
  end

  def handle_error(error, _stacktrace, _session_key, update, bot_state) do
    case error do
      %RuntimeError{} ->
        chat_id = MAX.Helper.extract_chat_id(update)
        post("/messages", %{text: error.message}, chat_id: chat_id)
        {:ok, bot_state}
      _ ->
        # MyBot.Admins.notify_admin(error, stacktrace, update, session_key, bot_state)
        {:ok, bot_state}
    end
  end

  def handle_timeout({_, chat_or_user_id}, bot_state) do
    post("/messages", %{text: "Bye"}, chat_id: chat_or_user_id)
    {:stop, bot_state}
  end
  
  # def session_key(update) do
  #   with {_update_type, %{chat: %{"chat_id" => chat_id}, user: %{"user_id" => user_id}}} <- MAX.Helper.extract_chat_user(update) do
  #     {chat_id, user_id} # With this key, every user in a group will have his own process.
  #   else
  #     _ ->
  #       chat_id = MAX.Helper.extract_chat_id(update)
  #       {:chat_id, chat_id}
  #   end
  # end

end