// Copyright 2023 Thomas Farvour. All rights reserved.
// Use of this source code is governed by the MIT license found in the root of
// this repository under LICENSE.md.

// A server configuration generator that creates compatible XML for
// the 7 Days to Die Server to consume for its configuration.

package main

import "github.com/farvour/7dtd-dedicated-server/tools/server-config-generator/cmd"

func main() {
	cmd.Execute()
}
