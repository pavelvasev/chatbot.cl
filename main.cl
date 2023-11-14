/*
  Метафора чата

  особенности

  F-CHAT-BOT
  Архитектура такая что есть чат и есть бот. Человек пишет в чат,
  это направляется боту. Бот реагирует и ответ пишет тоже в чат.
  Но бот не равно чат.

  F-CHAT-UPDATE
  обновлять ответ. т.е. сказали делаю.. и потом заменили на результат.

  F-CHAT-SIMPLE-CMD
  подача команд без ведущих спец-символов.
  это максимально простой подход для пользователя.
  и наиболее естественный. но
  + тогда полезно ввести команду комментария, чтобы система не ругалась F-CHAT-COMMENT
  + чтобы скопировать и вставить чат, надо экранировать сообщения системы командой комментария F-CHAT-PASTE-COMMENT
*/

/* сообщение чата msg это словарь с полями
   - type: cmd, reply, error
   - text: текст HTML сообщения для пользователя
   - args: разные дополнительные параметры
*/

// F-CHAT-COMMENT
// todo: это по идее параметр бота и все. И ему кстати такую команду можно добавить. Пользователь сможет добавить.
// а для чата - параметры "добавка в ответах бота" будет лучше.
// итого этот COMMENT_SYMBOL надо вообще убрать.
COMMENT_SYMBOL : const '//'

// записи для бота-сборщика.
mixin "tree_node"
process "bot_command" {
  in {
    code: cell     // код команды на английском
    gui_code: cell // код команды для пользователя (на русском)
    params: cell ""   // параметры (для пояснения)
    info: cell ""  // пояснение
    action: cell   // функция которую вызывать при поступлении команды
  }
}

// бот выражений
/* выполняет набор команд по очереди.
   если команда возвращает then-able объект, 
   то ждет его завершения перед переходом к следующей команде
*/
mixin "tree_node"
process "expression_bot" {
  in {
    chat: cell
    next_bot: cell
  }

  func "cmd" {: text args |
      // задача по text понять сколько там команд и вызвать следующий бот
      // args передается только первой команде

      let the_next_bot = self.next_bot.get()
    
      function process_command( lines,args ) 
      {
        if (lines.length == 0) return;
        let line = lines[0];
        //console.log("chat: sending command",line)
        return Promise.resolve( the_next_bot.cmd(line,args) ).then( x => {
          if (lines.length == 1) return x;
          //console.log("chat: command resolved, result is",x)
          return process_command( lines.slice(1) )
        })
      }

      let lines = text.split(/[\n;]/);
      let id
      if (lines.length > 1) 
          id = chat.get().log("Выполняю выражение...")

      let q = process_command( lines,args );

      //Promise.resolve(q).then( () => { if (id) chat.get().delete(id) } )

      return q;
  :}

  func "translate_to_gui" {: code |
    let the_next_bot = self.next_bot.get()
    return the_next_bot.translate_to_gui( code )
  :}

}

// бот
// чтобы добавить команду в бот, надо добавить ему узел-ребенок вида bot_command
mixin "tree_node"
process "bot" {
  in {
    chat: cell novalue=true
    cf&: cell
  }

  apply_children @cf

  commands_by_code := reduce @self.children (dict) {: value index acc |
    acc[ value.code.get() ] = value
    return acc
  :}

  commands_by_gui_code := reduce @self.children (dict) {: value index acc |
    acc[ value.gui_code.get() ] = value
    return acc
  :}

  //print "@self.children=" @self.children

  func "translate_to_gui" {: code |
    let c = commands_by_code.get()[ code ]
    if (c?.gui_code?.is_set) return c.gui_code.get();
    return code
  :}

  // хорошо бы статически прицепиться. тогда проверка типов будет.
  // но для этого надо явно выписать команды
  func "cmd" {: text args |
    text = text.trim()
    let words = text.split(/\s+/)
    let code = words[0];

    if (code == '') return;

    //if (words[0] == COMMENT_SYMBOL || val[0] == COMMENT_SYMBOL)
    //console.log("checking line",line)
    if (text.startsWith(COMMENT_SYMBOL))
      code = 'comment'
    else 
    {
      text = words.slice(1).join(' ')
    }

    if (code == "comment") return;

    let command_object = commands_by_gui_code.get()[ code ] || commands_by_code.get()[ code ]
    if (!command_object) {
        chat.get().error( `Команды '${code}' нет в таблице программы.`)        
        return 
    }

    let fn = command_object.action.is_set ? command_object.action.get() : null
    if (!fn) {
      chat.get().error( `Команда '${code}' - функция не установлена!`)
      return
    }

    console.log("bot: calling fn",fn)

    return fn( text, ...(args || []) )
  :}
}

// это у нас не просто бот, а бот-сборщик
// а в целом бот это то что имеет функцию cmd(msg)
/*
process "bot_v1" {
  in {
    chat: cell novalue=true
  }
  in {
    // команды чата
    commands: cell // dict code -> func 
    aliases: cell (dict) // другие имена dict новоеимя -> старое
  }

  // хорошо бы статически прицепиться. тогда проверка типов будет.
  // но для этого надо явно выписать команды
  func "cmd" {: msg |
    // логика обработки. но мб это отдельный бот да и все.
    let fn = commands.get()[ msg.code ]
    if (!fn) {
      if (msg.code != "free") // особый код которому разрешается не быть
        chat.get().error( `Команды с кодом ${code} нет в таблице чата!`)
      return
    }
    //args ||= []
    //console.log("chat:",msg)
    // по идее надо чат в параметрах передавать
    return fn( msg.text, ...(msg.args || []) )
  :}
}
*/

// а не проще ли было бы сделать 3-4 вида каналов: cmd, reply, error.. ?
process "chat" {

  in {
  	// бот чата
    bot: cell
  }

  history: cell []
  message: channel  
  // структура message:
  // type: cmd | reply
  // code, text, args
  // id
  update_message: channel // F-CHAT-UPDATE
  // структура - новое message с таким-же id

  init {:
    self.counter = 0 
  :}

  // хорошо бы статически прицепиться. тогда проверка типов будет.
  // но для этого надо явно выписать команды
  func "cmd" {: code text ...args |

    // переведем для гуи
    code = bot.get().translate_to_gui( code )
    if (code.length > 0) code = code + " ";
    text = code + (text || "")

  	// для визуализации
  	let msg = { type: 'cmd', text, args, id: self.counter++ }

    // если мы выводим в лог, то в браузере отладка возможна
    console.log("chat: cmd:",msg)

    //console.log("chat msg submitting msg=",msg)
  	message.submit( msg ) // там ее порисуют
  	// это для истории. но вопрос надо ли
  	history.submit( [...history.get(), msg] )

    // передаём команду боту

    return self.bot.get().cmd( text, args )
  :}

  // хорошо бы статически прицепиться. тогда проверка типов будет.
  // но для этого надо явно выписать команды
  func "user" {: text ...args |
    
    // для визуализации
    let msg = { type: 'cmd', text, args, id: self.counter++ }

    message.submit( msg ) // там ее порисуют
    // это для истории. но вопрос надо ли
    history.submit( [...history.get(), msg] )

    // передаём команду боту
    return self.bot.get().cmd( text, args )
  :}  

  func "reply" {: text args |
  	// для визуализации    
  	let msg = { type: 'reply', text, args, id: self.counter++ }
    //console.log("chat: reply:",msg)
    //console.log("chat msg submitting reply=",msg)
  	message.submit( msg ) // там ее порисуют
  	// это для истории. но вопрос надо ли    
  	history.submit( [...history.get(), msg] )
    return msg.id;
  :}

  // ну мне привычнее так писать
  func "log" {: text args |
    return reply( text, args )
  :}

  // F-CHAT-UPDATE
  func "update" {: id text args |
    let existing = history.get().find( x => x.id == id)
    if (existing) {
      existing = {...existing} // надо новый экземпляр чтобы дальше по ячейкам проходило
      existing.text = text
      //console.log("chat: update:",existing)
      if (args) existing.args = args
      update_message.submit( existing )
    }
  :}

  func "error" {: text args |
  	// для визуализации
  	let msg = { type: 'error', text, args, id: self.counter++ }
  	message.submit( msg ) // там ее порисуют
  	// это для истории. но вопрос надо ли
  	history.submit( [...history.get(), msg] )
    console.error( text )
  :}

}