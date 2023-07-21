<?php
class m120907_162016_goal extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_goal')) {
        	$this->createTable('tbl_goal', array(
				'id' => 'pk',
				'target' => 'string NULL',
				'description' => 'text NULL',
				'duration_total' => 'string NULL',
				'achieved' => 'boolean NULL',
				'client_id' => 'integer NOT NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('client_id', 'tbl_goal', 'client_id', false);				

			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_goal')) {
        	$this->dropTable('tbl_goal');
        }
    }
}