# matterbridge

[Matterbridge](https://github.com/42wim/matterbridge) is a communication bridge
between many different message platforms ("mattermost, IRC, gitter, xmpp, slack,
discord, telegram, rocketchat, twitch, ssh-chat, zulip, whatsapp, keybase,
matrix, microsoft teams, nextcloud, mumble, vk and more")

It can be used to bridge a specific room on matrix to a specific room on IRC,
and vice-versa. A bot user account forwards messages between both channels. So
the message will appear to be from a bot, not from the username that sent the
message, and the bot prepends the message with the original username instead
(configurable). It does not fascilitate private messages outside of the channel.

[heisenbridge](https://github.com/hifi/heisenbridge) may be a better option for
a single user account bridge and that supports private messages.

## Setup

Copy `.env-dist` to `.env_${DOCKER_CONTEXT}_default` and edit the variables.

The example is for bridging a single Matrix channel to a single IRC channel. You
can adapt the template for other networks.

 * Create a Matrix account
   * Create a private matrix channel, and copy its ID. (In Element its under the
     channel properties, advanced tab.) It looks like
     `!some-long-id@matrix-homeserver-domain.com`
 * Create an IRC account, register the account with NickServ.
 * Enter the account details for both accounts into the
   `.env_${DOCKER_CONTEXT}_default` as per the example.
 * Setup the gateways. Gateways are the mapping of the channels between two accounts.
   * Change `MATRIX_ROOM_1` to your matrix room name ID.
   * Change `IRC_ROOM_1` to the channel name on IRC (Lowercase. Should start
     with at least one `#`)

Run `make install` to start it. 
