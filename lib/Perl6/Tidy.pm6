class Perl6::Tidy {
	use nqp;

	has $.debugging = False;

	# convert-hex-integers is just a sample.
	role Formatter {
		has Bool $.convert-hex-integers = False;
	}

	method assert-Int( $name, Mu $parsed ) {
		say "$name:\n" ~ $parsed.Int if $.debugging;
		die "$name is not a Int" unless $parsed.Int;
	}

	method assert-Str( $name, Mu $parsed ) {
		say "$name:\n" ~ $parsed.Str if $.debugging;
		die "$name is not a Str" unless $parsed.Str;
	}

	method assert-hash( $name, Mu $parsed, &sub ) {
		say "$name:\n" ~ $parsed.dump if $.debugging;
		die "$name is not a hash" unless $parsed.hash;

		&sub($parsed)
	}

	method assert-hash-key( $name, $key, Mu $parsed, &sub ) {
		die "$name does not have key '$key'" unless $parsed.hash.{$key};

		&sub($parsed)
	}

	method assert-hash-with-key( $name, $key, Mu $parsed, &sub ) {
		die "$name is not a hash" unless $parsed.hash;

                self.assert-hash-key( $name, $key, $parsed, &sub );
	}

	method assert-list( $name, Mu $parsed, &sub ) {
		die "$name is not a list" unless $parsed.list;

		if $.debugging {
			for $parsed.list {
				say $name ~ "[]:\n" ~ $_.dump;
			}
		}

		&sub($parsed)
	}

	method tidy( Str $text ) {
		my $compiler := nqp::getcomp('perl6');
		my $g := nqp::findmethod($compiler,'parsegrammar')($compiler);
		#$g.HOW.trace-on($g);
		my $a := nqp::findmethod($compiler,'parseactions')($compiler);

		my $root = $g.parse( $text, :p( 0 ), :actions( $a ) );
		die "root is not a hash"
			unless $root.hash;
		die "root does not have a statementlist"
			unless $root.hash.<statementlist>;

		my $statementlist =
			self.statementlist( $root.hash.<statementlist> );
say $statementlist.perl;
	}

	class StatementList is Formatter {
		has $.statement;
	}

	method statementlist( Mu $parsed ) {
		self.assert-hash-with-key( 'statementlist', 'statement', $parsed, {
			self.statement( $parsed.hash.<statement> )
		} )
	}

	class Statement is Formatter {
		has @.items;
	}

	method statement( Mu $parsed ) {
		self.assert-list( 'stateement', $parsed, {
			my @items;
			for $parsed.list {
				self.assert-hash-with-key( 'statement', 'EXPR', $_, {
					my $expr = self.EXPR( $_.hash.<EXPR> );
					@items.push( $expr )
				} )
			}
			Statement.new(
				:items(
					@items
				)
			)
		} )
	}

	class EXPR is Formatter {
		has @.items;
	}

	method EXPR( Mu $parsed ) {
		self.assert-hash( 'EXPR', $parsed, {
			if $parsed.hash.<longname> and
			   $parsed.hash.<args> {
				self.longname-args(
					$parsed.hash.<longname>,
					$parsed.hash.<args>
				)
			}
			elsif $parsed.hash.<identifier> and
			      $parsed.hash.<args> {
				self.identifier-args(
					$parsed.hash.<identifier>,
					$parsed.hash.<args>
				)
			}
			elsif $parsed.hash.<value> {
				self.value( $parsed.hash.<value> )
			}
			elsif $parsed.list {
				my @items;
				for $parsed.list {
					my $item = self.EXPR-item( $_ );
					@items.push( $item )
				}
				EXPR.new(
					:items(
						@items
					)
				)
			}
		} )
	}

	method EXPR-item( Mu $parsed ) {
		self.assert-hash-with-key( 'EXPR-item', 'value', $parsed, {
			self.value( $parsed.hash.<value> )
		} )
	}

	method value( Mu $parsed ) {
		self.assert-hash( 'value', $parsed, {
			if $parsed.hash.<quote> {
				self.quote( $parsed.hash.<quote> )
			}
			elsif $parsed.hash.<number> {
				self.number( $parsed.hash.<number> )
			}
			else {
	die "uncaught type";
			}
		} )
	}

	class Quote does Formatter {
		has $.value
	}

	method quote( Mu $parsed ) {
		self.assert-hash-with-key( 'quote', 'nibble', $parsed, {
			self.nibble( $parsed.hash.<nibble> )
		} )
	}

	class Nibble does Formatter {
		has $.value
	}

	method nibble( Mu $parsed ) {
		self.assert-Str( 'nibble', $parsed );
		Nibble.new(
			:value(
				$parsed.Str
			)
		)
	}

	method number( Mu $parsed ) {
		self.assert-hash-with-key( 'number', 'numish', $parsed, {
			self.numish( $parsed.hash.<numish> )
		} )
	}

	method numish( Mu $parsed ) {
		self.assert-hash-with-key( 'numish', 'integer', $parsed, {
			self.integer( $parsed.hash.<integer> )
		} )
	}

	method integer( Mu $parsed ) {
		self.assert-hash( 'integer', $parsed, {
			if $parsed.hash.<decint> {
				self.decint( $parsed.hash.<decint> )
			}
			elsif $parsed.hash.<hexint> {
				self.hexint( $parsed.hash.<hexint> )
			}
			else {
	die "uncaught type";
			}
		} )
	}

	class DecInt does Formatter {
		has $.value;
	}

	method decint( Mu $parsed ) {
		self.assert-Int( 'decint', $parsed );

		$parsed.Int
	}

	class HexInt does Formatter {
		has $.value;
	}

	method hexint( Mu $parsed ) {
		self.assert-Int( 'hexint', $parsed );

		HexInt.new(
			:value(
				$parsed.Int
			)
		)
	}

	method args( Mu $parsed ) {
		self.assert-hash-key( 'args', 'arglist', $parsed, {
			self.arglist( $parsed.hash.<arglist> )
		} )
	}

	class LongnameArgs does Formatter {
		has $.longname;
		has @.args;
	}

	method longname-args( Mu $longname, Mu $args ) {
		self.assert-Str( 'longname', $longname );
		self.assert-hash-key( 'args', 'arglist', $args, {
			LongnameArgs.new(
				:longname(
					$longname.Str
				),
				:args(
					self.args( $args )
				)
			)
		} )
	}

	method semiarglist( Mu $parsed ) {
die "No parsed" unless $parsed;
		self.assert-hash-key( 'semiarglist', 'arglist', $parsed, {
#say "semiarglist:\n" ~ $parsed.dump if $.debugging;
#
#			self.arglist( $parsed.hash.<arglist> )
1;
		} )
	}

	class IdentifierArgs does Formatter {
		has $.identifier;
		has @.semiarglist;
	}

	method identifier-args( Mu $identifier, Mu $semiarglist ) {
		self.assert-Str( 'identifier', $identifier );
		self.assert-hash-key( 'identifier-args', 'semiarglist', $semiarglist, {
			IdentifierArgs.new(
				:identifier(
					$identifier.Str
				),
				:semiarglist(
					self.semiarglist( $semiarglist.hash.<semiarglist> )
				)
			)
		} )
	}

	method arglist( Mu $parsed ) {
		self.assert-hash-key( 'arglist', 'EXPR', $parsed, {
			self.EXPR( $parsed.hash.<EXPR> )
		} )
	}
}
