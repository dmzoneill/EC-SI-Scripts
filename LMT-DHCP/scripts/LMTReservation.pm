package LMTReservation;

use strict;

use Time::Local;
use Class::Struct;
use CQPerlExt;
use LMTSession;

struct 'LMTReservation::Record' => {
    reservationID       => '$',
    reservationHeadline => '$',
    User_name           => '$',
    User_email          => '$',
    BeginDate           => '$',
    EndDate             => '$',
    AssetName           => '$',
    AssetID             => '$',
};

sub format_date {
    my ($db_format) = @_;
    my @split1      = split ' ', $db_format;
    my @split2      = split '-', $split1[0];
    my $day         = $split2[2];
    my $month       = $split2[1];
    my $year        = $split2[0];
    return " " . $day . "-" . $month . "-" . $year . " ";
}

sub unix_times_from_row {
    my ($result_set) = @_;
    my @begin_raw    = split ' ', $result_set->GetColumnValue(2);
    my @begin_parts  = split '-', $begin_raw[0];
    my @end_raw      = split ' ', $result_set->GetColumnValue(3);
    my @end_parts    = split '-', $end_raw[0];
    my $begin        = mktime(
        '0', '0', '0', $begin_parts[2],
        $begin_parts[1] - 1,
        $begin_parts[0] - 1900
    );
    my $end = mktime(
        '0', '0', '0', $end_parts[2],
        $end_parts[1] - 1,
        $end_parts[0] - 1900
    );
    return ( $begin, $end );
}

sub reservation_window {
    my ( $session, $start_offset, $end_offset, $end_text_month ) = @_;
    my $query = $session->BuildQuery("Reservation");
    $query->BuildField("ID");
    $query->BuildField("BeginDate");
    $query->BuildField("EndDate");

    my ( undef, undef, undef, $end_mday, $end_mon, $end_year ) =
      localtime( time + $end_offset );
    my ( undef, undef, undef, $start_mday, $start_mon, $start_year ) =
      localtime( time + $start_offset );

    my $start_text =
        int( $start_mon + 1 ) . "/"
      . $start_mday . "/"
      . int( 1900 + $start_year );
    my $end_month_for_text =
      defined $end_text_month ? $end_text_month : $end_mon;
    my $end_text =
        int( $end_month_for_text + 1 ) . "/"
      . $end_mday . "/"
      . int( 1900 + $end_year );

    my @date_range = ( $start_text, $end_text );
    my @complete   = ("Complete");
    my $complete_filter =
      $query->BuildFilterOperator($CQPerlExt::CQ_BOOL_OP_AND);
    my $date_filter =
      $complete_filter->BuildFilterOperator($CQPerlExt::CQ_BOOL_OP_OR);
    $complete_filter->BuildFilter( "state", $CQPerlExt::CQ_COMP_OP_NOT_IN,
        \@complete );
    $date_filter->BuildFilter( "BeginDate", $CQPerlExt::CQ_COMP_OP_BETWEEN,
        \@date_range );
    $date_filter->BuildFilter( "EndDate", $CQPerlExt::CQ_COMP_OP_BETWEEN,
        \@date_range );

    my $start_unix =
      mktime( '0', '0', '0', $start_mday, $start_mon, $start_year );
    my $end_unix   = mktime( '0', '0', '0', $end_mday, $end_mon, $end_year );
    my $result_set = $session->BuildResultSet($query);
    $result_set->Execute();
    return ( $result_set, $start_unix, $end_unix, $start_mon );
}

sub classify_window {
    my ( $result_set, $start_unix, $end_unix, $mode, $buckets ) = @_;
    my $status = $result_set->MoveNext();

    while ( $status == 1 ) {
        my ( $begin_unix, $end_time ) = unix_times_from_row($result_set);
        my $id = $result_set->GetColumnValue(1);

        if ( $mode eq "next_week" ) {
            print "NEXT WEEK \n";

            if ( $begin_unix == $start_unix ) {
                print "BEGINS ON THIS DAY NEXT WEEK \n";
                push @{ $buckets->{begin} }, $id;
            }

            if ( $end_time == $end_unix ) {
                print "ENDS ON THIS DAY NEXT WEEK \n";
                push @{ $buckets->{end} }, $id;
            }
        }
        else {
            if ( $begin_unix == $start_unix ) {
                push @{ $buckets->{begin_today} }, $id;
            }
            if ( $begin_unix == $end_unix ) {
                push @{ $buckets->{begin_tomorrow} }, $id;
            }
            if ( $end_time == $start_unix ) {
                push @{ $buckets->{end_today} }, $id;
            }
            if ( $end_time == $end_unix ) {
                push @{ $buckets->{end_tomorrow} }, $id;
            }
        }

        $status = $result_set->MoveNext();
    }

    return;
}

sub asset_identity {
    my ( $session, $reservation_asset, $reservation_crb ) = @_;
    my ( $title, $id );

    if ( $reservation_asset ne "" ) {
        my $asset_entity = $session->GetEntity( "Asset", $reservation_asset );
        $title = $asset_entity->GetFieldValue("assetTitle")->GetValue();
        $id    = $asset_entity->GetFieldValue("id")->GetValue();
    }
    elsif ( $reservation_crb ne "" ) {
        my $crb_entity = $session->GetEntity( "EE_DUT", $reservation_crb );
        $title = $crb_entity->GetFieldValue("Headline")->GetValue();
        $id    = $crb_entity->GetFieldValue("id")->GetValue();
    }

    return ( $title, $id );
}

sub ip_addresses {
    my ( $session, $reservation_ips ) = @_;
    my @addresses;

    foreach my $ip ( @{$reservation_ips} ) {
        my $ip_entity = $session->GetEntity( "IPAddress", $ip );
        my $ip_addr   = $ip_entity->GetFieldValue("IPAddress")->GetValue();
        push @addresses, $ip_addr;
    }

    return @addresses;
}

sub build_record {
    my (%fields) = @_;
    return LMTReservation::Record->new(
        reservationID       => $fields{id},
        reservationHeadline => $fields{headline},
        User_name           => $fields{user_name},
        User_email          => $fields{user_email},
        BeginDate           => format_date( $fields{begin} ),
        EndDate             => format_date( $fields{end} ),
        AssetName           => $fields{asset_name},
        AssetID             => $fields{asset_id},
    );
}

sub print_reservation {
    my (
        $label,     $reservation_id, $headline,
        $user_name, $user_email,     $begin_raw,
        $end_raw,   $asset_name,     $asset_id
    ) = @_;
    print $label . "\n";
    print $reservation_id . "\n";
    print $headline . "\n";
    print $user_name . "\n";
    print $user_email . "\n";
    print format_date($begin_raw) . "\n";
    print format_date($end_raw) . "\n";
    print "Asset CRB Name: " . $asset_name . "\n";
    print "Asset CRB IXA: " . $asset_id . "\n";
    return;
}

sub send_notice {
    my (%args)      = @_;
    my $session     = $args{session};
    my $reservation = $args{reservation};
    my $res_entity =
      $session->GetEntity( "Reservation", $reservation->reservationID );
    my $res_id       = $reservation->reservationID;
    my $res_headline = $reservation->reservationHeadline;
    my $res_begin    = $reservation->BeginDate;
    my $res_end      = $reservation->EndDate;
    my $user_name    = $reservation->User_name;
    my $user_email   = $reservation->User_email;
    my $asset_name   = $reservation->AssetName;
    my $asset_id     = $reservation->AssetID;
    my $ip_list      = "";

    if ( defined $args{fixed_ip_list} ) {
        $ip_list = $args{fixed_ip_list};
    }
    else {
        foreach my $ip_address ( @{ $args{ip_addresses} } ) {
            $ip_list .= "<strong>" . $ip_address . "</strong>, ";
        }

        if ( $ip_list eq "" ) {
            $ip_list = $args{empty_ip_list};
        }
        else {
            $ip_list = substr $ip_list, 0, length($ip_list) - 2;

            if ( defined $args{ip_suffix} && $args{ip_suffix} ne "" ) {
                $ip_list .= $args{ip_suffix};
            }
        }
    }

    my $database_set_name =
      $session->GetSessionDatabase()->GetDatabaseSetName();
    my $database_name   = $session->GetSessionDatabase()->GetDatabaseName();
    my $entity_def_name = $res_entity->GetEntityDefName();
    my $res_url         = $args{base_url};
    $res_url .= '?command=GenerateMainFrame&service=CQ';
    $res_url .= "&schema=$database_set_name&contextid=$database_name";
    $res_url .= "&entityDefName=$entity_def_name&entityID=$res_id";

    my $subject = " Reservation: " . $res_headline . $args{subject_tail};
    my $mailer  = $args{mailer};
    my $common  = $args{common};
    $mailer->loadTemplate( $args{template} );
    $mailer->setSubject(
        $common->get( 'emailoptions', 'email_subject-prefix' ) . $subject );
    $mailer->setSendTo(
        $user_email . "," . $common->get( 'contacts', 'email_level1' ) );
    $mailer->setSendFrom( $common->get( 'contacts', 'email_level1' ) );

    my %replace = (
        "res_Headline",  $res_headline, "res_ID",      $res_id,
        "asset_Name",    $asset_name,   "asset_ID",    $asset_id,
        "res_BeginDate", $res_begin,    "res_EndDate", $res_end,
        "user_Name",     $user_name,    "ip_List",     $ip_list,
        "res_URL",       $res_url,
    );
    $mailer->replaceThese(%replace);
    $mailer->sendEmail();
    return;
}

sub handle_notices {
    my (%args) = @_;
    my $session = $args{session};

    foreach my $reservation ( @{ $args{reservations} } ) {
        my $res_entity = $session->GetEntity( "Reservation", $reservation );
        my $begin      = $res_entity->GetFieldValue("BeginDate")->GetValue();
        my $end        = $res_entity->GetFieldValue("EndDate")->GetValue();
        my $headline   = $res_entity->GetFieldValue("Headline")->GetValue();
        my $asset      = $res_entity->GetFieldValue("AssetRef")->GetValue();
        my $crb        = $res_entity->GetFieldValue("CRBRef")->GetValue();
        my ( $asset_name, $asset_id ) =
          asset_identity( $session, $asset, $crb );
        my @ips;

        if ( $args{collect_ips} ) {
            my $ip_refs = $res_entity->GetFieldValue("IPRef")->GetValueAsList();
            @ips = ip_addresses( $session, $ip_refs );
        }

        my $user_id     = $res_entity->GetFieldValue("User")->GetValue();
        my $user_entity = $session->GetEntity( "users", $user_id );
        my $user_name   = $user_entity->GetFieldValue("fullname")->GetValue();
        my $user_email  = $user_entity->GetFieldValue("email")->GetValue();
        my $record      = build_record(
            id         => $reservation,
            headline   => $headline,
            user_name  => $user_name,
            user_email => $user_email,
            begin      => $begin,
            end        => $end,
            asset_name => $asset_name,
            asset_id   => $asset_id,
        );

        print_reservation(
            $args{label}, $reservation, $headline,
            $user_name,   $user_email,  $begin,
            $end,         $asset_name,  $asset_id
        );

        my %notice = %args;
        $notice{reservation}  = $record;
        $notice{ip_addresses} = \@ips;
        send_notice(%notice);
    }

    return;
}

sub reserve_unless_reserved {
    my ( $session, $asset_entity ) = @_;

    if ( $asset_entity->GetFieldValue("State")->GetValue() ne "Reserved" ) {
        printf( "Asset: %s is not in reserved state when it should be\n",
            $asset_entity->GetFieldValue("id")->GetValue() );
        LMTSession::apply_action( $session, $asset_entity, "Reserved" );
    }

    return;
}

1;
