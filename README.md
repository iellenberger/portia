portia
======

Ports inspired *nix package manager

Our Spiel
---------

Do any of these describe you?

* Do you want to roll packages for your own use but get frustrated with the arcane nature of DEBs, RPMs and the like?
* Do you like ports but it isn't available on your flavor of *nix?
* Do you manage a buttload of servers and need a managed distribution and installation system for your packages?
* Does your environment have a numerous flavors of *nix?

If you said yes to one or more of these, Portia may be for you.

### What is Portia?

Portia is a package manager that will run on almost any flavor of *nix.
It is specifically designed to accommodate the needs of system administrators and package builders targeting private networks.

**Portia** ...

* ... **will run on almost any \*nix-based system**.
* ... **has nominal dependencies**.
As long as you have Bash and the [standard Perl distribution](http://perldoc.perl.org/perlmodlib.html#Standard-Modules), you should be good to go.
Portia's own distribution is fully self contained ... and most importantly: no [CPAN](http://www.cpan.org/), a *must* for private networks.
* ... **doesn't require you to know Perl.**
Many of you \*HATE* Perl (for misguided reasons, mostly) but don't worry - if you're an end user, package builder or system administrator, you'll never see a single line of Perl.
You may want to bone up on your Bash though.

Where We Are Today
------------------

Portia has been deployed in a number of corporate environments to date (names withheld) and is stable.
The biggest thing missing is decent documentation.
Over the next few months, I plan to finally get the docs in place so others can more easily enjoy the goodness.

Links
-----

* **[Documentation](doc/README.md)** - For all audiences: end users, package builders, system administrators and core developers.