#!/usr/bin/env python3

import logging
import os
from pathlib import Path
from typing import Any, Mapping, Optional

import jinja2
import yaml

__all__ = [
    "create_jinja2_template_env",
    "template_rendered",
    "merge_dict",
    "StartServerTemplates",
]

SERVER_HOME = os.environ.get("SERVER_HOME")
SERVER_INSTALL_DIR = os.environ.get("SERVER_INSTALL_DIR")
SERVER_DATA_DIR = os.environ.get("SERVER_DATA_DIR")

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.FileHandler(filename=f"{__file__}.log"), logging.StreamHandler()],
)
logger = logging.getLogger("StartServerTemplates")


def merge_dict(
    d1: Mapping[Any, Any], d2: Mapping[Any, Any], stringify_vals: bool = False
) -> Mapping[Any, Any]:
    """
    A simple shallow dictionary merger that replaces/appends values in d1 with
    those overridden or combined in d2 and returns the resulting output dict.
    """
    if stringify_vals:
        for v in d1.values():
            v = str(v)
        for v in d2.values():
            v = str(v)
    return {**d1, **d2}


def create_jinja2_template_env(searchpath: str = "./templates") -> jinja2.Environment:
    """
    Creates a usable template environment for Jinja2.
    """
    return jinja2.Environment(loader=jinja2.FileSystemLoader(searchpath=searchpath))


def template_rendered(
    template_env: jinja2.Environment,
    template_file: str,
    template_data: Optional[Mapping[str, str]] = None,
) -> str:
    """
    Utilize Jinja2 to produce a data field for a ConfigMap resource.
    Mostly useful for taking templates and turning them into fields used in
    the data: {} payload.
    """
    template = template_env.get_template(template_file)
    return template.render(template_data)


class StartServerTemplates(object):
    """
    Represents a template replacement helper class when starting the
    7 Days to Die Server.

    This class simply takes a list of TEMPLATES and
    injects the correct data (which usually comes from environment variables)
    into the template then renders the actual resulting output that the
    game server consumes.
    """

    TEMPLATES = [
        {
            "output_file": "serverconfig.xml",
            "output_dir": SERVER_INSTALL_DIR,
            "template_search_path": SERVER_HOME,
        },
        {
            "output_file": "serveradmin.xml",
            "output_dir": os.path.join(SERVER_DATA_DIR, "Saves"),
            "template_search_path": SERVER_HOME,
        },
    ]

    def __init__(self, *, output_file: str, template_env: jinja2.Environment):
        """
        Initializes the start server template file writer.
        """
        logger.info(
            f"Initializing the configuration file template replacer for {output_file}."
        )
        self.template_env = template_env
        self.output_file = output_file
        self.template_file = f"{output_file}.j2"
        template_config_values_file = f"{output_file}.values.yml"
        logger.info(
            f"Processing {self.output_file} template and writing to {output_file}."
        )
        try:
            self.template_config_values = yaml.safe_load(
                Path(SERVER_HOME, template_config_values_file).open("r")
            )
        except Exception:
            logger.error(
                f"Missing or unloadable values file {template_config_values_file} for template {self.template_file}."
            )
            raise
        logger.info(f"Values file {template_config_values_file} found and loaded.")
        template_config_values_override_file = f"{output_file}.values.override.yml"
        # This may not exist, trap the error.
        try:
            self.template_config_values_override = yaml.safe_load(
                Path(SERVER_HOME, template_config_values_override_file).open("r")
            )

            logger.info(
                f"Values override file {template_config_values_override_file} found and loaded."
            )
        except Exception:
            self.template_config_values_override = {}
            logger.info("No values override file found.")
        self.merged_template_data = merge_dict(
            self.template_config_values,
            self.template_config_values_override or {},
        )
        logger.debug("Merged template data result:")
        logger.debug(self.merged_template_data)

    @classmethod
    def render_all(cls):
        """
        Render all templates applicable and output to the base files.
        """
        logger.info("Rendering all templates.")
        for t in cls.TEMPLATES:
            template_search_path = t["template_search_path"]
            template_env = create_jinja2_template_env(searchpath=template_search_path)
            output_file = t["output_file"]
            output_dir = t["output_dir"]
            # template_data = self.override_values_from_env(template_data)
            cls(
                output_file=output_file,
                template_env=template_env,
            ).render(output_file=str(Path(output_dir, output_file).resolve()))
        logger.info("Rendered all templates.")

    def render(self, *, output_file: str) -> None:
        """
        Render a template file.
        """
        out = template_rendered(
            template_env=self.template_env,
            template_file=self.template_file,
            template_data=self.merged_template_data,
        )
        f = open(output_file, "w")
        f.write(out)
        f.close()

    def override_values_from_env(self, vals: Mapping[str, Any]) -> Mapping[str, Any]:
        """
        Iterate through all environment variables w/ prefix to see if
        we are overriding there too.

        This allows a user to set their own values in a dotenv file and they
        can get picked up by the script to update the template file accordingly
        even after the docker image is build.
        """
        o = {}
        for k, v in vals.items():
            o[k] = v
            # First, make sure the overrideable value is something we can
            # unserialize from the environment variable. Currently only
            # string, int and bool is supported.
            if not isinstance(v, (str, int, bool)):
                continue
            for env_key in os.environ.keys():
                cmp_key = f"SDTD_{k.upper()}"
                if env_key.upper() == cmp_key:
                    logger.info(
                        f"Located override value '{os.environ[env_key]}' for {cmp_key}, using it."
                    )
                    if isinstance(v, bool):
                        o[k] = bool(os.environ[env_key])
                    elif isinstance(v, int):
                        o[k] = int(os.environ[env_key])
                    else:
                        o[k] = os.environ[env_key]
        return o


def main():
    StartServerTemplates.render_all()


if __name__ == "__main__":
    main()
