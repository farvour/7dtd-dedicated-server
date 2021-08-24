#!/usr/bin/env python3

from typing import Any, Dict

import jinja2
import os
import yaml

__all__ = [
    "create_jinja2_template_env",
    "template_rendered",
    "merge_dict",
    "StartServerTemplates",
]

SERVER_HOME = os.environ.get("SERVER_HOME")
SERVER_INSTALL_DIR = os.environ.get("SERVER_INSTALL_DIR")
SERVERCONFIG_VALUES_FILE = "serverconfig.xml.values.yml"
SERVERCONFIG_VALUES_OVERRIDE_FILE = "serverconfig.xml.values.override.yml"


def merge_dict(
    d1: Dict[Any, Any], d2: Dict[Any, Any], stringify_vals: bool = False
) -> Dict[Any, Any]:
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

    template_loader = jinja2.FileSystemLoader(searchpath=searchpath)
    template_env = jinja2.Environment(loader=template_loader)

    return template_env


def template_rendered(
    template_env: jinja2.Environment, template_file: str, template_data: Dict = {}
) -> str:
    """
    Utilize Jinja2 to produce a data field for a ConfigMap resource.
    Mostly useful for taking templates and turning them into fields used in
    the data: {} payload.
    """

    template = template_env.get_template(template_file)
    out = template.render(template_data)

    return out


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
            "template_file": "serverconfig.xml.j2",
            "template_search_path": SERVER_HOME,
            "output_file": os.path.join(SERVER_INSTALL_DIR, "serverconfig.xml"),
        },
    ]

    def __init__(self):
        """
        Initializes the start server template file writer.
        """

        print("Initializing the configuration file template replacer.")

        self.template_config_values = yaml.safe_load(
            open(os.path.join(SERVER_HOME, SERVERCONFIG_VALUES_FILE), "r")
        )

        print(f"Values file {SERVERCONFIG_VALUES_FILE} found and loaded.")

        # This may not exist, trap the error.
        try:
            self.template_config_values_override = yaml.safe_load(
                open(os.path.join(SERVER_HOME, SERVERCONFIG_VALUES_OVERRIDE_FILE), "r")
            )

            print(f"Values override file {SERVERCONFIG_VALUES_OVERRIDE_FILE} found and loaded.")

        except Exception:
            self.template_config_values_override = {}

            print("No values override file found.")

    def render_all(self):
        """
        Render all templates applicable and output to the base files.
        """

        print("Rendering all templates...")

        for t in self.TEMPLATES:
            template_search_path = t["template_search_path"]
            template_file = t["template_file"]
            output_file = t["output_file"]

            print(f"Processing {template_file} and writing to {output_file}.")

            template_data = merge_dict(
                self.template_config_values.get(template_file, {}),
                self.template_config_values_override.get(template_file, {}),
            )

            template_data = self.override_values_from_env(template_data)

            self.render(
                template_env=create_jinja2_template_env(
                    searchpath=template_search_path
                ),
                template_file=template_file,
                template_data=template_data,
                output_file=output_file,
            )

        print("Rendered all templates.")

    def render(
        self,
        template_env: jinja2.Environment,
        template_file: str,
        template_data: Dict[str, Any],
        output_file: str,
    ):
        """
        Render a template file.
        """

        out = template_rendered(
            template_env=template_env,
            template_file=template_file,
            template_data=template_data,
        )

        f = open(output_file, "w")
        f.write(out)
        f.close()

    def override_values_from_env(self, vals: Dict[Any, Any]) -> Dict[Any, Any]:
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
                    print(
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
    start_server_templates = StartServerTemplates()
    start_server_templates.render_all()


if __name__ == "__main__":
    main()
