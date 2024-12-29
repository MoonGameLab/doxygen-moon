use inc::Module::Install 0.92;

name      'Doxygen-Moon';
all_from  'lib/Doxygen/Moon.pm';
author    q{Tourahi Amine <tourahi.amine@gmail.com>};
license   'to-do';

install_script 'bin/moon2dox';
auto_install;

repository 'https://github.com/MoonGameLab/doxygen-moon';
WriteAll;
