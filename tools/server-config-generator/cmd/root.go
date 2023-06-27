package cmd

import (
	"fmt"
	"os"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "server-config-generator",
	Short: "A server configuration generator for 7 Days to Die Server to consume.",
	Long:  `A server configuration generator that creates compatible XML for the 7 Days to Die Server to consume for its configuration.`,
}

func init() {
	// Initialize Cobra.
	cobra.OnInitialize(initConfig)

	// Configure JSON logging for all the things.
	log.SetFormatter(&log.JSONFormatter{})
	// log.SetLevel(log.DebugLevel)
}

func initConfig() {}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

// Merges two simple maps together with the last key of same value winning.
func mergeMaps[K comparable, V any](m1 map[K]V, m2 map[K]V) map[K]V {
	merged := make(map[K]V)
	for key, val := range m1 {
		merged[key] = val
	}
	for key, val := range m2 {
		merged[key] = val
	}
	return merged
}
