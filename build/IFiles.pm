package B::Utils::Install::Files;

$self = {
          'typemaps' => [
                          'typemap'
                        ],
          'inc' => '',
          'libs' => '',
          'deps' => []
        };


# this is for backwards compatiblity
@deps = @{ $self->{deps} };
@typemaps = @{ $self->{typemaps} };
$libs = $self->{libs};
$inc = $self->{inc};

	$CORE = undef;
	foreach (@INC) {
		if ( -f $_ . "/B/Utils/Install/Files.pm") {
			$CORE = $_ . "/B/Utils/Install/";
			last;
		}
	}

1;
