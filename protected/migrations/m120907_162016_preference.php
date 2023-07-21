<?php
class m120907_162016_preference extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_preference')) {
        	$this->createTable('tbl_preference', array(
				'id' => 'pk',
				'preferred_trainer_rel' => 'integer NULL',
				'preferred_language_rel' => 'integer NULL',
				'preferred_location_rel' => 'integer NULL',
				'client_id' => 'integer NOT NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('client_id', 'tbl_preference', 'client_id', true);				

			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_preference')) {
        	$this->dropTable('tbl_preference');
        }
    }
}