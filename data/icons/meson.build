application_id = 'io.github.lainsce.Emulsion'

scalable_dir = join_paths('scalable')
install_data(
  join_paths(scalable_dir, ('@0@.svg').format(application_id)),
  install_dir: join_paths(get_option('datadir'), scalable_dir)
)

symbolic_dir = join_paths('symbolic')
install_data(
  join_paths(symbolic_dir, ('@0@-symbolic.svg').format(application_id)),
  install_dir: join_paths(get_option('datadir'), symbolic_dir)
)
