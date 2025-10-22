defmodule Najva do
  @moduledoc """
  Najva keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def start() do
    Najva.XmppClient.start_link(%{
      jid: "najva_test0@conversations.im",
      password: "random_password",
      host: "conversations.im",
      resource: "Najva"
      # host: "xmpp.earth" has SCRAM-SHA-256-PLUS
    })
  end

  def start1() do
    Najva.XmppClient.start_link(%{
      jid: "najva_test1@conversations.im",
      password: "random_password",
      host: "conversations.im",
      resource: "Najva"
    })
  end

  def listpane_content() do
    %{
      "friend1@server.com" => %{
        name: "Alice",
        last_message: "See you tomorrow!",
        timestamp: "11:45"
      },
      "groupchat@conference.server.com" => %{
        name: "Project Team",
        last_message:
          "Don't forget the meeting. It is very important and we have a lot to discuss.",
        timestamp: "10:02"
      },
      "friend2@server.com" => %{name: "Bob", last_message: "Sounds good.", timestamp: "Yesterday"},
      "friend3@server.com" => %{
        name: "mAlice",
        last_message: "See you tomorrow!",
        timestamp: "11:45"
      },
      "groupchat1@conference.server.com" => %{
        name: "Project Team1",
        last_message:
          "Don't forget the meeting. It is very important and we have a lot to discuss.",
        timestamp: "10:02"
      },
      "friend4@server.com" => %{name: "Bob", last_message: "Sounds good.", timestamp: "Yesterday"},
      "friend5@server.com" => %{
        name: "Alice",
        last_message: "See you tomorrow!",
        timestamp: "11:45"
      },
      "groupchat3@conference.server.com" => %{
        name: "Project Team2",
        last_message:
          "Don't forget the meeting. It is very important and we have a lot to discuss.",
        timestamp: "10:02"
      },
      "friend6@server.com" => %{name: "Bob", last_message: "Sounds good.", timestamp: "Yesterday"},
      "friend7@server.com" => %{
        name: "Alice",
        last_message: "See you tomorrow!",
        timestamp: "11:45"
      },
      "groupchat4@conference.server.com" => %{
        name: "Project Team3",
        last_message:
          "Don't forget the meeting. It is very important and we have a lot to discuss.",
        timestamp: "10:02"
      },
      "friend8@server.com" => %{name: "Bob", last_message: "Sounds good.", timestamp: "Yesterday"},
      "friend9@server.com" => %{
        name: "Alice",
        last_message: "See you tomorrow!",
        timestamp: "11:45"
      },
      "groupchat5@conference.server.com" => %{
        name: "Project Team",
        last_message:
          "Don't forget the meeting. It is very important and we have a lot to discuss.",
        timestamp: "10:02"
      },
      "friend10@server.com" => %{
        name: "Bob",
        last_message: "Sounds good.",
        timestamp: "Yesterday"
      },
      "friend11@server.com" => %{
        name: "Alice",
        last_message: "See you tomorrow!",
        timestamp: "11:45"
      },
      "groupchat6@conference.server.com" => %{
        name: "Project Team",
        last_message:
          "Don't forget the meeting. It is very important and we have a lot to discuss.",
        timestamp: "10:02"
      },
      "friend12@server.com" => %{
        name: "Bob",
        last_message: "Sounds good.",
        timestamp: "Yesterday"
      },
      "friend13@server.com" => %{
        name: "Alixe",
        last_message: "See you tomorrow!",
        timestamp: "11:45"
      },
      "groupchat7@conference.server.com" => %{
        name: "Project Team",
        last_message:
          "Don't forget the meeting. It is very important and we have a lot to discuss.",
        timestamp: "10:02"
      },
      "friend14@server.com" => %{
        name: "Bob",
        last_message: "Sounds good.",
        timestamp: "Yesterday"
      },
      "friend15@server.com" => %{
        name: "Alice",
        last_message: "See you tomorrow!",
        timestamp: "11:45"
      },
      "groupchat8@conference.server.com" => %{
        name: "Project Team",
        last_message:
          "Don't forget the meeting. It is very important and we have a lot to discuss.",
        timestamp: "10:02"
      },
      "friend16@server.com" => %{
        name: "Bob",
        last_message: "Sounds good.",
        timestamp: "Yesterday"
      }
    }
  end
end
