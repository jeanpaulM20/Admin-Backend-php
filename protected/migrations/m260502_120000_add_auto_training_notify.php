<?php

class m260502_120000_add_auto_training_notify extends CDbMigration
{
	public function up()
	{
		$this->addColumn('tbl_client', 'auto_training_notify', 'TINYINT(1) NOT NULL DEFAULT 0');
	}

	public function down()
	{
		$this->dropColumn('tbl_client', 'auto_training_notify');
	}
}
