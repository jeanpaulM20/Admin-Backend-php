<?php
class m120907_162016_account extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_account')) {
        	$this->createTable('tbl_account', array(
				'id' => 'pk',
				'session_attended' => 'integer NULL',
				'session_paid' => 'integer NULL',
				'status' => 'string NULL',
				'client_id' => 'integer NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('client_id', 'tbl_account', 'client_id', true);				

			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_account')) {
        	$this->dropTable('tbl_account');
        }
    }
}