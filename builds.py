import itertools
import string


def parse_variables_from_template(template):
    """Parses variables from template string and returns list of variable names.

    >>> parse_variables_from_template("flu_h3n2")
    []
    >>> parse_variables_from_template("{virus}")
    ['virus']
    >>> parse_variables_from_template("{virus}_{lineage}")
    ['virus', 'lineage']
    """
    formatter = string.Formatter()
    return [item[1]
            for item in list(formatter.parse(template))
            if item[1] is not None]

def prepare_builds(builds):
    """Returns a list of complete build definitions for a given list of build templates.

    >>> builds = prepare_builds([{"name": "{virus}", "virus": ["zika"]}])
    >>> [sorted(build.items()) for name, build in builds.items()]
    [[('name', 'zika'), ('virus', 'zika')]]

    Build names should be the combinatorial product of the variables in the
    build name template.

    >>> builds = prepare_builds([{"name": "{virus}_{lineage}", "virus": ["zika"], "lineage": ["one", "two"]}])
    >>> sorted(builds.keys())
    ['zika_one', 'zika_two']

    When variables aren't reference in the build name, the build should be
    interpreted as is.

    >>> builds = prepare_builds([{"name": "zika", "virus": "zika"}])
    >>> [sorted(build.items()) for name, build in builds.items()]
    [[('name', 'zika'), ('virus', 'zika')]]
    """
    new_builds = {}

    for build in builds:
        # Find variables in build name template.
        variables = parse_variables_from_template(build["name"])

        # Confirm that all variables are defined as lists in the config.
        for variable in variables:
            assert isinstance(build[variable], list), "Variable '%s' is not a list: '%s'" % (variable, build[variable])

        # Find non-variables.
        non_variables = set(build.keys()) - set(variables + ["name"])

        # Create all combinations of variables defined in the build name
        # template as one would with a nested for loop. For example, if virus
        # and lineage are variables, all pairwise combinations of values from
        # those two variables will be produced (e.g., `[("flu", "h3n2")]`).
        variable_product = list(itertools.product(*[build[variable] for variable in variables]))

        # Assign variable names to the resulting product of variable values so
        # we know "flu" is a "virus", etc.
        named_variable_product = [dict(zip(variables, product)) for product in variable_product]

        for product in named_variable_product:
            # Create a dictionary from the current combination of variables
            new_build = product

            # Create the specific build name from the build name template.
            new_build["name"] = build["name"].format(**product)

            # Process all non-variable strings as potential templates that can
            # reference any of the build's variables and add processed
            # non-variables to the specific build config.
            for non_variable in non_variables:
                new_build[non_variable] = build[non_variable].format(**product)

            # Create new build entry indexed by name with variable and
            # non-variable dictionaries merged.
            new_builds[new_build["name"]] = new_build

    return new_builds
