package LMTSession;

use strict;

use CQPerlExt;

sub open_session {
    my ($lmtcommon) = @_;
    my $login       = $lmtcommon->get( 'database', 'cq_login' );
    my $pass        = $lmtcommon->get( 'database', 'cq_pass' );
    my $db          = $lmtcommon->get( 'database', 'cq_db' );
    my $dbset       = $lmtcommon->get( 'database', 'cq_dbset' );

    my $cq      = CQClearQuest::Build();
    my $runmode = $cq->GetPerlReturnStringMode();
    $cq->SetPerlReturnStringMode($CQPerlExt::CQ_RETURN_STRING_UNICODE);

    my $session = CQSession::Build();
    CQSession::UserLogon( $session, "$login", "$pass", "$db", "$dbset" );
    return $session;
}

sub for_each_result {
    my ( $session, $entity, $fields, $callback ) = @_;
    my $query = $session->BuildQuery($entity);

    foreach my $field ( @{$fields} ) {
        $query->BuildField($field);
    }

    my $result_set = $session->BuildResultSet($query);
    $result_set->Execute();
    my $status = $result_set->MoveNext();

    while ( $status == 1 ) {
        $callback->($result_set);
        $status = $result_set->MoveNext();
    }

    return;
}

sub apply_action {
    my ( $session, $entity, $action, $before_validate ) = @_;
    $session->EditEntity( $entity, $action );

    if ($before_validate) {
        $before_validate->($entity);
    }

    if ( $entity->Validate() eq "" ) {
        $entity->Commit();
    }
    else {
        $entity->Revert();
    }

    return;
}

1;
