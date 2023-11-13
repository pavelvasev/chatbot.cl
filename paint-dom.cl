////////////////////////////////// визуализация чата

import dom="dom" cb="./main.cl"

mixin "tree_lift"
process "chat_styles" {
  dom.element "style" `
  .chat_msg {
      border: 1px solid grey;
      border-radius: 7px 7px 7px 0px;
      padding: 3px;
      margin: 0px 4px 4px 4px;
      background: white;
      color: black;

      overflow-wrap: anywhere; 
  }
  .chat_cmd {
    align-self: end;
    border-radius: 7px 7px 0px 7px;
    max-width: 80%;
    text-align: right;
  }
  .chat_reply {    
    background: #cbedb7;
  }
  
  .chat_error {
    background: red;
  }

  .chat_sender {
    padding: 2px;
    color: purple;
    user-select: none;
  }
  .chat_label {
    padding: 2px;
    color: green;
  }
  .show_chat_messages {
    background: grey;
    align-items: flex-start;
    display: flex; 
    flex-direction: column; 
    border: 1px solid; 
    
    height: 300px; 
    overflow-y: scroll;
    resize: vertical;
  }
  `
  // F-EXPAND-CHAT resize: vertical
  // max-height: 200px;
}


mixin "tree_node"
process "show_chat_msg" {
  in {
    msg: cell
  }
  func "msg2cmsg" {: msg |
       let content = msg.text || ""

       content = content.replaceAll("\n","<br/>")
       //content = `<pre>${content}</pre>`

       //if (msg.code && msg.code != "comment") content = "<strong>" + msg.code + "</strong> " + content
       if (msg.code) {
          if (msg.code !== "comment")
              content = msg.code + " " + content
       }
       else  // экранирование ответов бота - F-CHAT-PASTE-COMMENT
       if (msg.type == "reply")
          content = `<span style='font-size:0'>${cb.COMMENT_SYMBOL} ответ:</span> ` + content
       else
       if (msg.type == "error")
          content = `<span style='font-size:0'>${cb.COMMENT_SYMBOL} ошибка:</span> ` + content
       return {type: msg.type, content, id: msg.id}
  :}

  cmsg := msg2cmsg @msg 

  output := dom.element "div"
    //id=(+ "msg_id_" (get @msg "id"))
    className=(+ "chat_msg" " chat_" (get @cmsg "type")) 
    innerHTML=(get @cmsg "content")
    //print "mmmsg=" @msg
  /*
  {
    //dom.element "span" (get @msg "sender") className="chat_sender"
    //dom.element "span" (+ "/" (get @msg "code") " ") className="chat_label"
    //dom.element "span" (get @msg "value" | get "text")
  }
  */
}

// визуализация сообщений чата
mixin "tree_node"
process "show_chat_messages" {
  in {
    //chat: cell
    ///chat_message: channel
    chat: const
  }

  output := show_messages: dom.element "div" className="show_chat_messages"
      {
    
    //chat_message := get @chat "message"    
    //chat_message := apply {: c | console.log('ggg',c.message); return c.message :} @chat
    func "append_message" {: msg |         
         let m = create_show_chat_msg({msg})
         //console.log("appending message",msg)
         show_messages.append( m )

         // прокрутка вниз.. но надо бы еще проверять что пользователь не откатил наверх
         // надо таймаут а то там не сразу обновляется
         setTimeout( () => {
          let objDiv = show_messages.output.get()
          objDiv.scrollTop = objDiv.scrollHeight;
          }, 200 )
    :}

    react @chat.message @append_message

    //react @chat.message {: msg | console.log("painter: see chat message",msg) :}

    react @chat.update_message {: newmsg |
       let c = show_messages.children.get()
       let existing = c.find( x => x.msg.get().id == newmsg.id )       
       if (existing)
           existing.msg.submit( newmsg )
    :}

    init {:
      chat.history.get().forEach( x => append_message(x))
    :}
  }
}

/*
mixin "tree_node"
process "send_chat_messages" {
  in {
    chat: const
  }
 
  output := dom.row style="gap: 5px;" {
    // текстовый ввод
    txt: dom.input "text" style="flex: 1;"
    //bind (dom.event @txt.output "change") @process
    bind @txt.enter @process

    btn: dom.element "button" "Ввод" style="flex: 0.25;"
    bind (dom.event @btn.output "click") @process

    process: channel
    react @process {:
      let val = txt.value.get()
      //console.log("see val",val)
      if (!txt.value.is_set || val == "") return; // не отправлять если ввод пуст

      txt.input_value.submit("") // чистим чат
      let label = 'free'
      if (val[0] == '/') {
         let s = val.split(' ')
         label = s[0].slice(1)
         val = s.slice(1).join(' ')
      }   
      chat.cmd( label,val )
    :}
  }
}
*/

// отправка сообщений пользователем в чат
// F-CHAT-SIMPLE-CMD
mixin "tree_node"
process "send_chat_messages_input" {
  in {
    chat: const
  }
 
  output := dom.row style="gap: 5px;" {
    // текстовый ввод
    txt: dom.input "text" style="flex: 1;"
    //bind (dom.event @txt.output "change") @process
    bind @txt.enter @process

    btn: dom.element "button" "Ввод" style="flex: 0.25;"
    bind (dom.event @btn.output "click") @process

    process: channel
    react @process {:
      let val = txt.value.get()
      //console.log("see val",val)
      if (!txt.value.is_set || val == "") return; // не отправлять если ввод пуст

      txt.input_value.submit("") // чистим чат

      chat.user( val )
    :}
  }
}

// отправка сообщений пользователем в чат из textarea
// todo объединить с input - по идее это вообще параметр
// F-CHAT-SIMPLE-CMD
mixin "tree_node"
process "send_chat_messages" {
  in {
    chat: const
  }
 
  output := dom.row style="gap: 5px;" {
    // текстовый ввод
    txt: dom.textarea style="flex: 1; font-size: large;"
    //bind (dom.event @txt.output "change") @process
    bind @txt.enter @process

    dom.textarea_auto_height @txt.output
    // см также https://stackoverflow.com/questions/657795/how-to-remove-word-wrap-from-textarea

    btn: dom.element "button" "Ввод" style="flex: 0.25;"
    bind (dom.event @btn.output "click") @process

    process: channel
    react @process {:
      let val = txt.value.get()
      //console.log("see val",val)
      if (!txt.value.is_set || val == "") return; // не отправлять если ввод пуст

      txt.input_value.submit("") // чистим чат

      chat.user( val )

    :}
  }
}