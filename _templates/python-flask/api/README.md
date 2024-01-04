# Flask API container source files

 * The [Dockerfile](Dockerfile) builds the container image.

 * The [pyproject.toml](pyproject.toml) specifies all the dependencies.

 * The [poetry.lock](poetry.lock) locks the exact versions.

 * The [app](app) directory contains our main flask module.

   * [app/__init__.py](app/__init__.py) contains the main flask app router.

   * [app/database](app/database.py) contains the datbase client code.
   
   * [app/templates](app/templates) contains the Jinja templates
