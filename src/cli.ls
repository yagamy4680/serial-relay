#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[fs path]>
require! <[yargs colors]>
{ConfigManager} = require \./helpers/config

config = global.config = new ConfigManager {}

argv =
  yargs
    .scriptName 'sr'
    .commandDir 'cmds', {extensions: <[js ls]>}
    .demandCommand!
    .help!
    .argv