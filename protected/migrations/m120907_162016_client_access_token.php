<?php
class m120907_162016_client_access_token extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_client_access_token')) {
        	$this->createTable('tbl_client_access_token', array(
				'id' => 'pk',
				'token' => 'string NULL',
				'date' => 'datetime NULL',
				'sort' => 'integer NULL DEFAULT \'0\'',
				'client_id' => 'integer NOT NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('sort', 'tbl_client_access_token', 'sort', false);				
			$this->createIndex('client_id', 'tbl_client_access_token', 'client_id', false);				

			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_client_access_token')) {
        	$this->dropTable('tbl_client_access_token');
        }
    }
}