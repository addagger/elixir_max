defmodule MAX.Helper do

  # update_type: "message_callback", "message_created", "message_edited"
  def extract_chat_id(%{"message" => %{"recipient" => %{"chat_id" => chat_id}}}) do
    chat_id
  end

  # update_type: "message_removed", "bot_added", "bot_removed", "chat_title_changed", "user_added", "user_removed", "bot_started"
  def extract_chat_id(%{"chat_id" => chat_id}) do
    chat_id
  end

  # update_type: "message_chat_created"
  def extract_chat_id(%{"chat" => %{"chat_id" => chat_id}}) do
    chat_id
  end

  # unknown format
  def extract_chat_id(_update), do: nil

  # update_type: "message_callback": User is chat's owner if chat_type is 'dialog'
  def extract_chat_user(%{"update_type" => update_type, "message" => %{"recipient" => %{"chat_id" => chat_id, "chat_type" => "dialog"}}, "callback" => %{"user" => %{"user_id" => user_id} = user}, "user_locale" => user_locale}) do
    {update_type, %{chat: %{"chat_id" => chat_id, "type" => "dialog", "owner_id" => user_id}, user: user, user_locale: user_locale}}
  end

  # update_type: "message_callback"
  def extract_chat_user(%{"update_type" => update_type, "message" => %{"recipient" => %{"chat_id" => chat_id, "chat_type" => chat_type}}, "callback" => %{"user" => %{"user_id" => _user_id} = user}, "user_locale" => user_locale}) do
    {update_type, %{chat: %{"chat_id" => chat_id, "type" => chat_type}, user: user, user_locale: user_locale}}
  end

  # update_type: "message_created": User is chat's owner if chat_type is 'dialog'
  def extract_chat_user(%{"update_type" => update_type, "message" => %{"recipient" => %{"chat_id" => chat_id, "chat_type" => "dialog"}, "sender" => %{"user_id" => user_id} = user}, "user_locale" => user_locale}) do
    {update_type, %{chat: %{"chat_id" => chat_id, "type" => "dialog", "owner_id" => user_id}, user: user, user_locale: user_locale}}
  end

  # update_type: "message_created"
  def extract_chat_user(%{"update_type" => update_type, "message" => %{"recipient" => %{"chat_id" => chat_id, "chat_type" => chat_type}, "sender" => %{"user_id" => _user_id} = user}, "user_locale" => user_locale}) do
    {update_type, %{chat: %{"chat_id" => chat_id, "type" => chat_type}, user: user, user_locale: user_locale}}
  end

  # update_type: "message_edited": User is chat's owner if chat_type is 'dialog'
  def extract_chat_user(%{"update_type" => update_type, "message" => %{"recipient" => %{"chat_id" => chat_id, "chat_type" => "dialog"}, "sender" => %{"user_id" => user_id} = user}}) do
    {update_type, %{chat: %{"chat_id" => chat_id, "type" => "dialog", "owner_id" => user_id}, user: user}}
  end

  # update_type: "message_edited"
  def extract_chat_user(%{"update_type" => update_type, "message" => %{"recipient" => %{"chat_id" => chat_id, "chat_type" => chat_type}, "sender" => %{"user_id" => _user_id} = user}}) do
    {update_type, %{chat: %{"chat_id" => chat_id, "type" => chat_type}, user: user}}
  end

  # update_type: "bot_added", "bot_removed", "chat_title_changed"
  def extract_chat_user(%{"update_type" => update_type, "chat_id" => chat_id, "user" => %{"user_id" => _user_id} = user}) do
    {update_type, %{chat: %{"chat_id" => chat_id}, user: user}}
  end

  # update_type: "message_removed"
  def extract_chat_user(%{"update_type" => update_type, "chat_id" => chat_id, "user_id" => user_id}) do
    {update_type, %{chat: %{"chat_id" => chat_id}, user: %{"user_id" => user_id}}}
  end

  # update_type: "user_added"
  def extract_chat_user(%{"update_type" => update_type, "chat_id" => chat_id, "inviter_id" => user_id}) do
    {update_type, %{chat: %{"chat_id" => chat_id}, user: %{"user_id" => user_id}}}
  end

  # update_type: "user_removed"
  def extract_chat_user(%{"update_type" => update_type, "chat_id" => chat_id, "admin_id" => user_id}) do
    {update_type, %{chat: %{"chat_id" => chat_id}, user: %{"user_id" => user_id}}}
  end

  # update_type: "bot_started"
  def extract_chat_user(%{"update_type" => update_type, "chat_id" => chat_id, "user" => %{"user_id" => _user_id} = user, "user_locale" => user_locale}) do
    {update_type, %{chat: %{"chat_id" => chat_id}, user: user, user_locale: user_locale}}
  end

  # update_type: "message_chat_created (dialog with user)"
  def extract_chat_user(%{"update_type" => update_type, "chat" => %{"chat_id" => _chat_id, "dialog_with_user" => %{"user_id" => user_id} = user} = chat}) do
    {update_type, %{chat: Map.put(chat, "owner_id", user_id) |> Map.delete("dialog_with_user"), user: user}}
  end

  # update_type: "message_chat_created (group chat)"
  def extract_chat_user(%{"update_type" => update_type, "chat" => %{"chat_id" => _chat_id, "owner_id" => user_id} = chat}) do
    {update_type, %{chat: chat, user: %{"user_id" => user_id}}}
  end

  # unknown format
  def extract_chat_user(%{"update_type" => update_type}) do
    {update_type, %{}}
  end

  def tmp_file(bot_module, token, option \\ nil) do
    System.tmp_dir() <> "#{bot_module}_#{encode_bot_id(bot_module, token)}_#{option}.tmp"
  end

  def webhook_path(bot_module, token) do
    "/max/#{encode_bot_id(bot_module, token)}"
  end

  def encode_bot_id(bot_module, token) do
    :crypto.hash(:sha, :erlang.term_to_binary([bot_module, token])) |> Base.url_encode64(padding: false)
  end

end