#!/usr/bin/env python3

import logging
import os
from pathlib import Path
from typing import Iterable
from xml.dom import minidom

import mergedeep
import yaml

SERVER_HOME: str = os.environ.get("SERVER_HOME", "")
SERVER_INSTALL_DIR: str = os.environ.get("SERVER_INSTALL_DIR", "")
SERVER_DATA_DIR: str = os.environ.get("SERVER_DATA_DIR", "")


logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.FileHandler(filename=f"{__file__}.log"), logging.StreamHandler()],
)
logger = logging.getLogger("ServerConfigGenerator")


class ServerConfigGenerator(object):
    """
    A server configuration generator that creates compatible XML for
    the 7 Days to Die Server to consume for its configuration.
    """

    CONFIGURATION_FILES = [
        {
            "values_in_file": "serverconfig.xml.values.in.yaml",
            "values_in_override_file": "serverconfig.xml.values.in.override.yaml",
            "out_file": "serverconfig.xml",
        },
        {
            "values_in_file": "serveradmin.xml.values.in.yaml",
            "values_in_override_file": "serveradmin.xml.values.in.override.yaml",
            "out_file": "serveradmin.xml",
        },
    ]

    def __init__(
        self, *, values_in_file: str, values_in_override_file: str, out_file: str
    ) -> None:
        """
        Initializes the configuration generator merger and writer with its
        necessary data.
        """
        logger.info(f"Initializing the configuration file generator for {out_file}")
        logger.debug("Merged value data result:")
        self.values_in_file = values_in_file
        self.values_in_override_file = values_in_override_file
        self.out_file = out_file
        # Load the base values file for configuration
        try:
            self.base_values = yaml.safe_load(
                Path(SERVER_HOME, self.values_in_file).open("r")
            )
            logger.info(f"Loaded values file {self.values_in_file}")
        except Exception:
            logger.error(
                f"Missing or unloadable values file {self.values_in_file} for configuration {self.out_file}"
            )
            raise
        # Attempt to load an override input if it's present
        try:
            self.override_values = yaml.safe_load(
                Path(SERVER_HOME, self.values_in_override_file).open("r")
            )
            logger.info(f"Loaded values override file {self.values_in_override_file}")
        except Exception:
            self.override_values = {}
            logger.warning("No values override file found or it is unloadable")
        # Merge the results of the base and the override with override winning
        # Note: arrays cannot be merged (yet) so last value will always win
        self.merged_values = {}
        mergedeep.merge(
            self.merged_values,
            self.base_values,
            self.override_values or {},
            strategy=mergedeep.Strategy.REPLACE,
        )
        logger.debug("Merged value result:")
        logger.debug(self.merged_values)

    def generate(self) -> None:
        """
        Generates an output XML configuration file.
        """
        if len(self.merged_values.keys()) > 1:
            raise ValueError(
                "The merged values should only have one top level key for the root element"
            )
        root_element_key = list(self.merged_values.keys())[0]
        root_element_name = root_element_key
        logger.debug(f"Creating XML element root for {root_element_name}")
        root = minidom.Document()
        xml = root.createElement(root_element_name)
        root.appendChild(xml)
        sub_elements = self.merged_values[root_element_key]
        for element_key, element_val in sub_elements.items():
            # logger.debug(f"Element key: {element_key}")
            # logger.debug(f"Element val: {type(element_val)} {element_val}")
            if isinstance(element_val, bool):
                element_val_str = "true" if element_val else "false"
            else:
                element_val_str = str(element_val)
            if root_element_name == "ServerSettings":
                e = root.createElement("property")
                e.setAttribute("name", element_key)
                e.setAttribute("value", element_val_str)
                logger.debug(
                    f"Created element property name={element_key}, value={element_val_str}"
                )
                xml.appendChild(e)
            elif root_element_name == "adminTools":
                e = root.createElement(element_key)
                if isinstance(element_val, Iterable):
                    for el_sub_val in element_val:
                        # logger.debug(
                        #     f"Element sub val: {el_sub_val} {type(el_sub_val)}"
                        # )
                        el_sub_name = list(el_sub_val.keys())[0]
                        el_sub = root.createElement(el_sub_name)
                        for k1, v1 in el_sub_val[el_sub_name].items():
                            el_sub.setAttribute(k1, str(v1))
                        logger.debug(f"Created element {el_sub_name} ")
                        e.appendChild(el_sub)
                xml.appendChild(e)
        xml_str = root.toprettyxml(encoding="UTF-8")
        with open(Path(SERVER_INSTALL_DIR, self.out_file), "wb") as of:
            of.write(xml_str)

    @classmethod
    def generate_all(cls):
        """
        Generates XML configuration for all possible game server configuration
        files.
        """
        logger.info("Generating all configurations")
        for c in cls.CONFIGURATION_FILES:
            values_in_file = c["values_in_file"]
            values_in_override_file = c.get("values_in_override_file", None)
            out_file = c["out_file"]
            cls(
                values_in_file=values_in_file,
                values_in_override_file=values_in_override_file or "",
                out_file=out_file,
            ).generate()
        logger.info("Generated all configurations")


def main():
    logging.info("Starting")
    ServerConfigGenerator.generate_all()
    logger.info("Done")


if __name__ == "__main__":
    main()
