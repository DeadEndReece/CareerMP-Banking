# 👑 CareerMP Banking

A server/client BeamMP banking module for CareerMP that adds a custom BeamNG UI app for player-to-player payments, live balance display, and incoming payment control.

## Features

- Custom `CareerMP Banking` UI app for Career mode.
- Live balance display pulled from the player's Career money.
- Online player list with direct send actions.
- Preset transfer amounts for faster payments.
- Incoming payments can be enabled or disabled from the app.
- Server-side session and rolling-window transaction limits to help prevent abuse.
- Small client-side send cooldown to reduce spam.
- Automatic app injection into supported BeamNG UI layouts.
- Movable and resizable app window with saved placement support.

## Installation

1. Download the latest release.
2. Extract it into your BeamMP server/client resources so these paths exist:
   - `Resources/Server/CareerMPBanking/careerMPBanking.lua`
   - `Resources/Client/CareerMPBanking.zip`
3. Start BeamMP with the module installed.
4. The banking app should be added to the Career Freeroam UI layout automatically.
5. If needed, open the BeamNG UI Apps menu and enable `CareerMP Banking`.

## What The App Does

Players can use the app to:

- View their current balance
- See other online players
- Send money directly to another player
- Use preset payment amounts
- Allow or block incoming payments

## Configuration

### Adjustable Server Amounts

The server-side limits for this release are hard-coded in:

`Resources/Server/CareerMPBanking/careerMPBanking.lua`

Adjust these values to change the transaction limits:

- `sessionTransactionMax = 100000`
  Maximum total amount a player can send in one session.
- `sessionReceiveMax = 200000`
  Maximum total amount a player can receive in one session.
- `shortWindowMax = 1000`
  Maximum amount allowed inside the short time window.
- `shortWindowSeconds = 30`
  Length of the short time window in seconds.
- `longWindowMax = 10000`
  Maximum amount allowed inside the long time window.
- `longWindowSeconds = 300`
  Length of the long time window in seconds.


## Notes

- Incoming payments default to enabled when a player joins.
- The player list excludes your own player entry.
- This release does not use a separate `settings.txt`; limits are edited directly in the Lua files above.
- The app starts closed by default and can be opened from its `B` tab.
