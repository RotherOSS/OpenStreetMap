# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# Copyright (C) 2019 Rother OSS GmbH, http://otrs.ch/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::OpenStreetMap;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get params
    my %GetParam;

    for my $Attribute ( $ParamObject->GetParamNames() ) {
        $GetParam{$Attribute} = $ParamObject->GetParam( Param => $Attribute );
    }

    #use Data::Dumper;
    #print STDERR "vo60 - GP: ".Dumper(\%GetParam);

    # AJAX function call
    if ( $GetParam{OriginalAction} ) {

        # get icon and location info
        my $OSMObject = $Kernel::OM->Get('Kernel::System::OpenStreetMap');

        my $JSON = $LayoutObject->BuildSelectionJSON(
            $OSMObject->GenerateResponse(%GetParam),
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # show module page
    else {

        my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

        # store last screen, used for backlinks
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => 'LastScreenView',
            Value     => $Self->{RequestedURL},
        );

        # get layout object
        my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

        #        # investigate refresh
        #        my $Refresh = $Self->{UserRefreshTime} ? 60 * $Self->{UserRefreshTime} : undef;

        # output header
        my $Output = $LayoutObject->Header(
            Title => Translatable('OpenStreetMap'),

            #            Refresh => $Refresh,
        );
        $Output .= $LayoutObject->NavigationBar();

        $Output .= $LayoutObject->Output(
            TemplateFile => 'OpenStreetMap',
        );

        # add footer
        $Output .= $LayoutObject->Footer();

        return $Output;

    }

}

1;
