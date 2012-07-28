= FUnit

* http://rubyforge.org/projects/nasarb
* http://nasarb.rubyforge.org/funit
* mailto:nasarb-developers@rubyforge.org

== DESCRIPTION:

FUnit is a unit testing framework for Fortran.

Unit tests are written as Fortran fragments that use a small
set of testing-specific keywords and functions.  FUnit transforms
these fragments into valid Fortran code, compiles, links, and
runs them against the code under test.

FUnit is
{opinionated software}[http://www.oreillynet.com/pub/a/network/2005/08/30/ruby-rails-david-heinemeier-hansson.html],
which values convention over configuration. Specifically, FUnit requires,

* a Fortran 95 compiler,
* tests to be stored along side the code under test, and
* test files to be named appropriately.

== FEATURES/PROBLEMS:

* Enables the Scientific Method for software by making unit testing
  Fortran fun and easy.
* Encourages cohesive, yet decoupled code paired with
  <em>executable</em> documentation.

== SYNOPSIS:

Suppose <tt>gas_physics.f90</tt> has a routine that returns
viscosity as a function of temperature, e.g.,

 module gas_physics
 contains
   function viscosity(temperature)
     real :: viscosity, temperature
     viscosity = 2.0e-3 * temperature**1.5
   end function
 end module

Tests of this module would be contained in <tt>gas_physics.fun</tt>,
and might contain a test like,

 test_suite gas_physics

 test viscosity_varies_as_temperature
  assert_real_equal(      0.0, viscosity(0.0) )
  assert_equal_within( 0.7071, viscosity(50.0), 1e-3 )
 end test

 end test_suite

This brief fragment is all you need.  The framework provides the rest
of the trappings to turn this into valid Fortran code.

You would run this unit test with the command,

 funit gas_physics

which would transform your fragments contained in <tt>gas_physics.fun</tt>
into valid Fortran code, create a test runner program, compile everything,
and run the tests, viz,

  expanding test suite: gas_physics... done.
  locating associated source files and sorting for compilation
  (cd .; g95   -c gas_physics_fun.f90)
  (cd .; g95   -c TestRunner.f90)
  g95  -o TestRunner gas_physics.o gas_physics_fun.o TestRunner.o

  gas_physics test suite:
  Passed 2 of 2 possible asserts comprising 1 of 1 tests.

This and other examples come with the FUnit distribution in the
<tt>examples</tt> directory.  There is also an emacs mode in
the <tt>utils</tt> directory.  If you installed the FUnit via Rubygems,
these directories can be found in your Rubygems library directory, e.g., <tt>/usr/local/lib/ruby/gems</tt>.

== REQUIREMENTS:

* Fortran 90/95/2003 compiler
* Ruby with Rubygems package manager
* The fortran Rubygem

== INSTALL:

* <tt>sudo gem install funit</tt>
* Set FC environment variable to point to a Fortran compiler:
  * <tt>export FC=/path/of/Fortran/compiler</tt> (sh)
  * <tt>setenv FC /path/of/Fortran/compiler</tt> (csh)
* Other influential environment variables: FCFLAGS and LDFLAGS

== LICENSE:

FUnit is released under the NASA Open Source Agreement -- see License.txt[link:files/License_txt.html] for details.

== ORIGIN:

On October 4, 2001, Mike Hill (then of {Object Mentor}[http://www.objectmentor.com/],
now of {Industrial Logic}[http://www.industriallogic.com]) visited {NASA Langley Research Center}[http://www.larc.nasa.gov]
in Hampton, Virginia and gave a test-first design talk at
the {Institute for Computer and Applied Sciences and Engineering (ICASE)}[http://www.icase.edu].
Copies of his slides are available at {icase.edu/series/MPP}[http://www.icase.edu/series/MPP/].

Mike spent the afternoon with Bil Kleb, Bill Wood, Karen Bibb, and
Mike Park reasoning out how we might create a testing framework
for Fortran 90 to use during FUN3D[http://fun3d.larc.nasa.gov] code development.
By the end of the afternoon we had a working prototype based
on the macro expansion techniques employed in Mike Hill's cpptestkit[http://sourceforge.net/projects/cpptestkit].
We quickly found C-preprocessor macros to be too restrictive and
rewrote the framework in Ruby[http://www.ruby-lang.org].

== TODO:

* To avoid Fortran's 32-character limit, don't add test name during translation
  or allow another method for naming longer tests altogether.
* Add assertions that capture stops, warning messages, and other exits.
* For compilation, use internal rake task instead of an external makefile.
* To increase portability, create stand-alone executables with Erik Veenstra's
  RubyScript2Exe[http://www.erikveen.dds.nl/rubyscript2exe/].
* Make FUnit self-tests fail gracefully if Fortran compiler is not found.
