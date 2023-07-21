<?php
class m120907_162016_metric extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_metric')) {
        	$this->createTable('tbl_metric', array(
				'id' => 'pk',
				'name' => 'string NULL',
				'type' => 'string NULL',
				'group' => 'string NULL',
				'file' => 'string NULL',
				
				'client_id' => 'integer NOT NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('client_id', 'tbl_metric', 'client_id', false);				

			
				
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_metric')) {
        	$this->dropTable('tbl_metric');
        }
    }
}