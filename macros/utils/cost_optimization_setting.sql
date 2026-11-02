{#-
  Reads one of the package's on/off settings, the ones that also switch models on and off
  in dbt_project.yml. On dbt v1, the package's dbt_project.yml can't see vars, so those
  settings can also be set as environment variables: DBT_COST_OPTIMIZATION_<NAME>, where
  <NAME> is the var name in upper case without a leading dbt_cost_optimization_.
  This macro applies the same rule as the dbt_project.yml gates, so a model and its gate
  always agree:
    - a setting that defaults to false is on when the var OR the env var is true;
    - a setting that defaults to true is off when the var OR the env var is false.
  Intentionally NOT dispatched: the rule is the same on every platform.
-#}
{% macro cost_optimization_setting(name, default) %}
    {% set suffix = name[22:] if name.startswith('dbt_cost_optimization_') else name %}
    {% set env_name = 'DBT_COST_OPTIMIZATION_' ~ suffix | upper %}
    {% set from_env = env_var(env_name, 'true' if default else 'false') | lower == 'true' %}
    {% if default %}
        {{ return(var(name, default) and from_env) }}
    {% else %}
        {{ return(var(name, default) or from_env) }}
    {% endif %}
{% endmacro %}
