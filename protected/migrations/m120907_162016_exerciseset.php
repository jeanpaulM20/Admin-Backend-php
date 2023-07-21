<?php
class m120907_162016_exerciseset extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_exerciseset')) {
        	$this->createTable('tbl_exerciseset', array(
				'id' => 'pk',
				'name' => 'string NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');

			
				if (!$this->getDbConnection()->getSchema()->getTable('tbl_exerciseset_exercise')) {
	$this->createTable('tbl_exerciseset_exercise', array(
		'exerciseset_id' => 'integer NOT NULL',
		'exercise_id' => 'integer NOT NULL',
		'PRIMARY KEY (exerciseset_id, exercise_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

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
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_exerciseset')) {
        	$this->dropTable('tbl_exerciseset');
        }
    }
}