#!/usr/bin/perl

# ==============================================================================
#   機能
#     Perl モジュールを一覧表示する
#   構文
#     USAGE 参照
#
#   Copyright (c) 2010-2017 Yukio Shiiya
#
#   This software is released under the MIT License.
#   https://opensource.org/licenses/MIT
# ==============================================================================

######################################################################
# 基本設定
######################################################################
use strict;
use warnings;

use Config;
use Cwd qw(abs_path);
use ExtUtils::MakeMaker;
use File::Basename;
use File::Find;
use File::Spec;
use Getopt::Long qw(GetOptionsFromArray :config gnu_getopt no_ignore_case);

my $s_err = "";
$SIG{__DIE__} = $SIG{__WARN__} = sub { $s_err = $_[0]; };

$SIG{WINCH} = "IGNORE";
$SIG{HUP} = $SIG{INT} = $SIG{TERM} = sub { POST_PROCESS();exit 1; };

my $SCRIPT_FULL_NAME = abs_path($0);
my ($SCRIPT_NAME, $SCRIPT_ROOT) = fileparse($SCRIPT_FULL_NAME);
my $PID = $$;

######################################################################
# 変数定義
######################################################################
my $curdir = File::Spec->curdir();

my @INC_DIR = grep {not m#^$curdir$#} @INC;
my $INC_DIR;
my $LEVEL = "module";

my @COLUMN = qw(name);
my %WIDTH = ();
$WIDTH{fullpath} = 72; $WIDTH{dir} = 32; $WIDTH{file} = 48; $WIDTH{name} = 48; $WIDTH{ver} = 12;
my $OPT;
my ($COLUMN, $WIDTH);
my $rc;

my $FLAG_OPT_NOHEADER = 0;

my $mod_pattern;
my %mod;
my @record;
my $record;

######################################################################
# 関数定義
######################################################################
sub PRE_PROCESS {
}

sub POST_PROCESS {
}

sub USAGE {
	print STDOUT <<EOF;
Usage:
    perl_mod_list.pl [OPTIONS ...] [MOD_PATTERN]

    MOD_PATTERN
       Specify pattern of module name to list specific modules in \@INC.
       Without MOD_PATTERN, all the installed modules in \@INC are listed.
       But in any cases mentioned above, if "$curdir" (=current directory) is
       included in \@INC, it is omitted in order to speed-up module search.
       (Specify include-directories option to include "$curdir" in module search
        directories.)

OPTIONS:
    -i, --include-directories=INC_DIR[$Config{path_sep}...]
       Specify module search directories they are used in place of \@INC.
    -l, --level={d|distribution,m|module}
       Specify the level to show in module information list.
       (default: $LEVEL)
    -s, --show=COLUMN[:WIDTH][,...]
       COLUMN : {fullpath|dir|file|name|ver}
       (default: name)
       WIDTH  : integer greater than or equal to 0
       (default: fullpath:$WIDTH{fullpath},dir:$WIDTH{dir},file:$WIDTH{file},name:$WIDTH{name},ver:$WIDTH{ver})
       Specify columns to show in module information list.
    --no-header
       Specifies that the column header should not be displayed in the output.
    --help
       Display this help and exit.
EOF
}

use Common_pl::Is_numeric;

######################################################################
# メインルーチン
######################################################################

# オプションのチェック
if ( not eval { GetOptionsFromArray( \@ARGV,
	"i|include-directories=s" => sub {
		@INC_DIR = split(/\Q$Config{path_sep}\E/, $_[1], -1);
	},
	"l|level=s" => sub {
		if ( $_[1] =~ m#^(?:d|distribution|m|module)$# ) {
			$LEVEL = $_[1];
		} else {
			print STDERR "-E Argument to \"-$_[0]\" is invalid -- \"$_[1]\"\n";
			USAGE();exit 1;
		}
	},
	"s|show=s" => sub {
		if ( $_[1] ne "" ) {
			@COLUMN = ();
			foreach $OPT (split(/,/, $_[1], -1)) {
				($COLUMN, $WIDTH) = split(/:/, $OPT, 2);
				if ( $COLUMN =~ m#^(?:fullpath|dir|file|name|ver)$# ) {
					push @COLUMN, $COLUMN;
					if ( defined($WIDTH) ) {
						$rc = IS_NUMERIC($WIDTH);
						if ( $rc != 0 ) {
							print STDERR "-E \"WIDTH\" parameter of \"$COLUMN\" not numeric -- \"$WIDTH\"\n";
							USAGE();exit 1;
						}
						if ( $WIDTH >= 0 ) {
							$WIDTH{$COLUMN} = $WIDTH;
						} else {
							print STDERR "-E \"WIDTH\" parameter of \"$COLUMN\" must be an integer greater than or equal to 0 -- \"$WIDTH\"\n";
							USAGE();exit 1;
						}
					}
				} else {
					print STDERR "-E \"COLUMN\" parameter in argument to \"-s\" or \"--show\" is invalid -- \"$COLUMN\"\n";
					USAGE();exit 1;
				}
			}
		} else {
			print STDERR "-E argument to \"-s\" or \"--show\" is missing\n";
			USAGE();exit 1;
		}
	},
	"no-header" => \$FLAG_OPT_NOHEADER,
	"help" => sub {
		USAGE();exit 0;
	},
) } ) {
	print STDERR "-E $s_err\n";
	USAGE();exit 1;
}

# 引数のチェック
if ( @ARGV > 1 ) {
	print STDERR "-E Wrong Number of arguments\n";
	USAGE();exit 1;
} elsif ( @ARGV == 1 ) {
	$mod_pattern = $ARGV[0];
} else {
	$mod_pattern = ".";
}

# 作業開始前処理
PRE_PROCESS();

#####################
# メインループ 開始 #
#####################

# NOHEADER オプションが指定されていない場合
if ( $FLAG_OPT_NOHEADER == 0 ) {
	@record = ();
	foreach $COLUMN (@COLUMN) {
		push @record, sprintf("%-$WIDTH{$COLUMN}s", $COLUMN);
	}
	$record = join " ", @record;
	print $record . "\n";
	$record = "=" x length($record);
	print $record . "\n";
}

# モジュール検索ディレクトリのループ
foreach $INC_DIR (@INC_DIR) {
	$INC_DIR =~ s#\\#/#g;
	find({ follow_fast => 1, wanted => sub {
		%mod = ();
		$mod{fullpath} = $File::Find::name;
		#if ( (-d) and (m#^[a-z]#) ) {
		#	$File::Find::prune = 1;
		#	return;
		#}
		if ( (-d) ) {
			if ( defined(opendir(DH, $mod{fullpath})) ) {
				closedir(DH);
			} else {
				print STDERR "-W \"" . File::Spec->canonpath($mod{fullpath}) . "\" cannot read directory: $!\n";
				return;
			}
		}
		if ( $LEVEL =~ m#^(?:d|distribution)$# ) {
			if ( not m#^\.packlist$# ) {
				return;
			}
			$mod{dir} = $INC_DIR;
			($mod{file} = $mod{fullpath}) =~ s#^$mod{dir}/##;
			if ( $mod{file} !~ m#^auto/# ) {
				return;
			}
			($mod{name} = $mod{file}) =~ s#^auto/##;
			$mod{name} =~ s#/.packlist$##;
			$mod{name} =~ s#/#::#g;
			if ( $mod{name} !~ m#$mod_pattern# ) {
				return;
			}
			# show=ver オプションが指定されている場合
			if ( (grep {m#^ver$#} @COLUMN) >= 1 ) {
				$mod{ver} = "N/A";
			}
		} elsif ( $LEVEL =~ m#^(?:m|module)$# ) {
			if ( not m#\.pm$# ) {
				return;
			}
			$mod{dir} = $INC_DIR;
			($mod{file} = $mod{fullpath}) =~ s#^$mod{dir}/##;
			($mod{name} = $mod{file}) =~ s#\.pm$##;
			$mod{name} =~ s#/#::#g;
			if ( $mod{name} !~ m#$mod_pattern# ) {
				return;
			}
			# show=ver オプションが指定されている場合
			if ( (grep {m#^ver$#} @COLUMN) >= 1 ) {
				if ( defined(open(FH, '<', $mod{fullpath})) ) {
					close(FH);
					$mod{ver} = MM->parse_version($mod{fullpath});
				} else {
					$mod{ver} = "<cannot read>";
					print STDERR "-W \"" . File::Spec->canonpath($mod{fullpath}) . "\" cannot read file: $!\n";
				}
			}
		}
		@record = ();
		foreach $COLUMN (@COLUMN) {
			if ( $COLUMN =~ m#^(?:fullpath|dir|file)$# ) {
				push @record, sprintf("%-$WIDTH{$COLUMN}s", File::Spec->canonpath($mod{$COLUMN}));
			} elsif ( $COLUMN =~ m#^(?:name|ver)$# ) {
				push @record, sprintf("%-$WIDTH{$COLUMN}s", $mod{$COLUMN});
			}
		}
		$record = join " ", @record;
		print $record . "\n";
	} }, $INC_DIR);
}

#####################
# メインループ 終了 #
#####################

# 作業終了後処理
POST_PROCESS();exit 0;

