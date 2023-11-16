Возможно объекту бота не нужен чат.
Он может получать чат в сообщении.

Сообразно вызов бота это сообщение с разными полями.
msg и там есть bot.
https://docs.aiogram.dev/en/latest/dispatcher/dispatcher.html
async def message_handler(message: types.Message) -> None:
    await SendMessage(chat_id=message.from_user.id, text=message.text)