#!/usr/bin/env perl

=encoding utf-8

=pod

=head1 NAME

B<pre-receive.nonasciifilenames.pl>

=head1 SYNOPSIS

Checks if filepath contains any nonascii letters and denies the push if it does. 

=head1 OPTIONS

Introduces a git config option that can be set with 

"git config hooks.allownonascii <true/false>" on the bare repo.

=head1 DESCRIPTION

This is a git pre-receive hook.
It checks if the proposed push contains any files with nonascii letters and denies the push if it does,
because nonascii letters are notoriously problematic with cross-platform git clients.

It basically does the same thing that the default pre-commit hook that you get with every git clone, 
but this is a pre-receive hook so it can be enforced on the serverside.
Since this is a pre-receive hook it can't use the same method as the default pre-commit hook.

I strongly recommend you also encourage users to install the pre-commit hook in their clone, 
since it's much more convenient to be denied before commit.

Notes about pre-receive hooks:
The pre-receive hook is _not_ called with arguments for each ref updated,
it recives on stdin a line of the format "oldrev newrev refname".

The value in oldrev will be 40 zeroes if the refname is propsed to be created (i.e. new branch)
The value in newrev will be 40 zeroes if the refname is propsed to be deleted (i.e. delete branch)
The values on both will be non-zero if refname is propsed to be updated

=head1 KNOWN ISSUES

If you use the config variable to allow some bad nonasciifilenames to be added to the repo,
and later configure it to deny those files, any future commit that would affect those files will be denied.
Workaround: Do no not change the variable back and forth, 
decide what you want to allow when you create the repo and leave it like that.

=head1 AUTHOR

Håkan Isaksson

=cut

use strict;
use warnings;

my $DEBUG=0;
my $denied=0;
my $denied_chars_regexp = qr/\\303/;  ### Special UTF-8 encoded chars starts with this

sub msg {
    my $msg = shift;
    print STDERR $msg."\n";
}

sub debug {
    my $msg = shift;
    msg "[DEBUG] $0: $msg" if $DEBUG;
}

#
# Sanity testing
#
if ( ! defined $ENV{GIT_DIR} ) {
    print "This is a git hook, and is not ment to run from the command line.\n";
    print "Copy or link this script to <repo>.git/hooks/ in a bare repo and name it pre-receive.\n";
    print "Make sure it has the execute bit set.\n";
    exit;
}

my $allownonascii = ( `git config hooks.allownonascii` ); chomp($allownonascii);
my $quotepath = ( `git config core.quotepath` ); chomp($quotepath);

if ($quotepath eq "off") {
    msg "$0: [ERROR] core.quotepath is off, it must be on to use this hook. \nUse \"git config core.quotepath on\" to turn it on.";
    exit(1);
}

#
# Check the file path in received commits and return 1 if denied, 0 if ok.
#
sub check_filepath {
    my ($oldrev, $newrev, $refname) = @_;

    debug("check_filepath: oldrev=$oldrev newrev=$newrev refname=$refname");
    debug("git config allownonascii is true") if $allownonascii eq "true";
    return 0 if $allownonascii eq "true";
    my $revs="$oldrev..$newrev";
    $revs=$newrev if $oldrev =~ /^0+$/;
    return 0 if $newrev =~ /^0+$/;
    return 0 if $oldrev =~ /^0+$/ and $refname eq "refs/heads/master"; ### empty repository
    debug("git diff --name-only $revs 2>/dev/null");

    for my $fname ( split /\n/, `git diff --name-only $revs 2>/dev/null` ) {
        debug("fname=$fname");
        if ( $fname =~ /$denied_chars_regexp/ ) {

            msg "Error: Attempt to add a non-ascii file name: $fname\n";
            msg "This can cause problems if you want to work";
            msg "with people on other platforms.\n";
            
            msg "To be portable it is advisable to rename the file ...\n";
            
            msg "If you know what you are doing you can disable this";
            msg "check on the serverside bare repo using:\n";
            msg "git config hooks.allownonascii true\n";

            return 1; # denied
        }
    }
    return 0;
}

#
# Main loop, receives input from git on STDIN
#
while (<>) {
    chomp;
    my ($oldrev, $newrev, $refname) = split(/ /);
    $denied = check_filepath($oldrev, $newrev, $refname);
}

debug "exit code = $denied\n" if $DEBUG eq 1;

exit($denied);
