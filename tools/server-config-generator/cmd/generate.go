package cmd

import (
	"io/ioutil"
	"os"
	"path/filepath"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

// generateCliParams are the command-line arguments for this subcommand.
type generateCliParams struct {
	// The current running cobra.Command
	cmd *cobra.Command

	outputDir string
}

var serverHome string
var serverInstallDir string
var serverDataDir string
var outputDirectory string

type ServerConfigValues struct {
	ServerSettings map[string]interface{} `yaml:"ServerSettings"`
}

type ServerAdminValues struct {
	AdminTools struct {
		Admins      []map[string]interface{} `yaml:"admins"`
		Permissions []map[string]interface{} `yaml:"permissions"`
		Whitelist   []map[string]interface{} `yaml:"whitelist"`
		Blacklist   []map[string]interface{} `yaml:"blacklist"`
	} `yaml:"adminTools"`
}

var generateCmd = &cobra.Command{
	Use:   "generate",
	Short: "Generate the server configuration files",
	Long:  `Generate the server configuration files.`,
	Run: func(cmd *cobra.Command, args []string) {
		outputDirectory = filepath.Join(generateFlags.outputDir)

		log.Info("Initializing the configuration file generator")
		log.Infof("Configuration files will be generated into: %v", outputDirectory)

		log.Info("Loading input YAML files for XML values")

		// Load the server config XML input value YAML file.
		serverConfigInputValues := loadServerConfigInputValues(false)
		serverConfigInputOverrideValues := loadServerConfigOverrideInputValues()
		log.Infof("Loaded ServerConfig %v", serverConfigInputValues)
		log.Infof("Loaded ServerConfig overrides %v", serverConfigInputOverrideValues)

		// Load the server admin XML input value YAML file.
		serverAdminInputValues := loadServerAdminInputValues(false)
		serverAdminInputOverrideValues := loadServerAdminOverrideInputValues()
		log.Infof("Loaded ServerAdmin %v", serverAdminInputValues)
		log.Infof("Loaded ServerAdmin overrides %v", serverAdminInputOverrideValues)

		m1 := map[string]string{
			"foo": "bar",
		}
		m2 := map[string]string{
			"foo":  "baz",
			"test": "test1",
		}

		m3 := mergeMaps(m1, m2)

		log.Infof("m3: %v", m3)
	},
}

var generateFlags generateCliParams

func init() {
	// Pull some defaults from the environment.
	serverHome = os.Getenv("SERVER_HOME")
	serverInstallDir = os.Getenv("SERVER_INSTALL_DIR")
	serverDataDir = os.Getenv("SERVER_DATA_DIR")

	if serverHome == "" {
		panic("You must set the SERVER_HOME environment variable")
	}

	if serverInstallDir == "" {
		panic("You must set the SERVER_INSTALL_DIR environment variable")
	}

	generateFlags = generateCliParams{}
	generateCmd.Flags().StringVarP(&generateFlags.outputDir, "output-dir", "o", serverHome, "Change the output directory of generated configuration files")

	rootCmd.AddCommand(generateCmd)
}

func loadServerConfigInputValues(override bool) ServerConfigValues {
	var serverConfigXmlInValuesFilename string

	if override {
		serverConfigXmlInValuesFilename = "serverconfig.xml.values.in.override.yaml"
	} else {
		serverConfigXmlInValuesFilename = "serverconfig.xml.values.in.yaml"
	}

	serverConfigXmlInValuesFile, err := ioutil.ReadFile(
		filepath.Join(serverHome, serverConfigXmlInValuesFilename))

	if err != nil {
		if override {
			log.Warnf("Could not load override file %v: %v",
				serverConfigXmlInValuesFilename, err)
		} else {
			log.Fatalf("Error loading %v: %v", serverConfigXmlInValuesFilename, err)
		}
	}

	serverConfigXmlInValues := &ServerConfigValues{}
	err = yaml.Unmarshal([]byte(serverConfigXmlInValuesFile), &serverConfigXmlInValues)

	log.Debugf("Loaded %v as %v", serverConfigXmlInValuesFilename, *serverConfigXmlInValues)

	return *serverConfigXmlInValues
}

func loadServerConfigOverrideInputValues() ServerConfigValues {
	return loadServerConfigInputValues(true)
}

func loadServerAdminInputValues(override bool) ServerAdminValues {
	var serverAdminXmlInValuesFilename string

	if override {
		serverAdminXmlInValuesFilename = "serveradmin.xml.values.in.override.yaml"
	} else {
		serverAdminXmlInValuesFilename = "serveradmin.xml.values.in.yaml"
	}

	serverAdminXmlInValuesFile, err := ioutil.ReadFile(
		filepath.Join(serverHome, serverAdminXmlInValuesFilename))

	if err != nil {
		if override {
			log.Warnf("Could not load override file %v: %v",
				serverAdminXmlInValuesFilename, err)
		} else {
			log.Fatalf("Error loading %v: %v", serverAdminXmlInValuesFilename, err)
		}
	}

	serverAdminXmlInValues := &ServerAdminValues{}
	err = yaml.Unmarshal([]byte(serverAdminXmlInValuesFile), &serverAdminXmlInValues)

	log.Debugf("Loaded %v as %v", serverAdminXmlInValuesFilename, *serverAdminXmlInValues)

	return *serverAdminXmlInValues
}

func loadServerAdminOverrideInputValues() ServerAdminValues {
	return loadServerAdminInputValues(true)
}
