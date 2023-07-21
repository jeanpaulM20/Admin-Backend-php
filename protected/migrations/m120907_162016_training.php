<?php
class m120907_162016_training extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_training')) {
        	$this->createTable('tbl_training', array(
				'id' => 'pk',
				'date' => 'date NULL',
				'starttime' => 'time NULL',
				'endtime' => 'time NULL',
				'type' => 'string NULL',
				'text' => 'text NULL',
				'status' => 'string NULL',
				'cancelled_at' => 'date NULL',
				'cancelled_by_client_rel' => 'integer NULL',
				'cancelled_by_trainer_rel' => 'integer NULL',
				'client_id' => 'integer NOT NULL',
				'location_id' => 'integer NOT NULL',
				'trainer_id' => 'integer NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('client_id', 'tbl_training', 'client_id', false);				
			$this->createIndex('location_id', 'tbl_training', 'location_id', false);				
			$this->createIndex('trainer_id', 'tbl_training', 'trainer_id', false);				

			
				
				if (!$this->getDbConnection()->getSchema()->getTable('tbl_training_exerciseset')) {
	$this->createTable('tbl_training_exerciseset', array(
		'training_id' => 'integer NOT NULL',
		'exerciseset_id' => 'integer NOT NULL',
		'PRIMARY KEY (training_id, exerciseset_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

				
			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_training')) {
        	$this->dropTable('tbl_training');
        }
    }
}