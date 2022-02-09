project('io.github.lainsce.Emulsion', 'vala',
        version: '3.2.2',
        meson_version: '>= 0.59.0'
)

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments([
		'--target-glib=2.68',
	],
	language: 'vala',
)

if get_option('development')
  app_id = 'io.github.lainsce.Emulsion.Devel'
  name_suffix = ' (Development)'
else
  app_id = 'io.github.lainsce.Emulsion'
  name_suffix = ''
endif

conf = configuration_data()
conf.set_quoted('APP_ID', app_id)
conf.set_quoted('NAME_SUFFIX', name_suffix)
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('GETTEXT_PACKAGE', app_id)
conf.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
conf.set10('DEVELOPMENT', get_option('development'))
configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

add_project_arguments(
  '-include', 'config.h',
  '-DGETTEXT_PACKAGE="@0@"'.format(app_id),
  language: 'c'
)

asresources = gnome.compile_resources(
  'as-resources', 'data/io.github.lainsce.Emulsion.gresource.xml',
  source_dir: 'data',
  c_name: 'as'
)

sources = [
  'src/main.vala',
  'src/manager.vala',
  'src/window.vala',
  'src/pid.vala',
  'src/utils.vala',
  'src/palette.vala',
  'src/color.vala',
  'src/coloreditpopover.vala',
  'src/portal.vala',
  'src/settings.vala',
]

dependencies = [
  dependency('gio-2.0'),
  dependency('gtk4'),
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gee-0.8'),
  dependency('libadwaita-1'),
  dependency('gmodule-2.0'),
  dependency('json-glib-1.0'),
  meson.get_compiler('c').find_library('m', required: true)
]

executable(
  meson.project_name(),
  sources,
  asresources,
  dependencies: dependencies,
  vala_args: [meson.project_source_root() + '/src/config.vapi'],
  install : true
)

subdir('data')
subdir('po')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true
)
