<?php
class m120907_162016_file extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_file')) {
        	$this->createTable('tbl_file', array(
				'id' => 'pk',
				'name' => 'string NULL',
				'date' => 'datetime NULL',
				'file' => 'string NULL',
				'client_id' => 'integer NOT NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('client_id', 'tbl_file', 'client_id', false);				

			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_file')) {
        	$this->dropTable('tbl_file');
        }
    }
}