<?php
class m120907_162016_exercise extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_exercise')) {
        	$this->createTable('tbl_exercise', array(
				'id' => 'pk',
				'name' => 'string NULL',
				'group' => 'string NULL',
				'subgroup' => 'string NULL',
				
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');

			
				if (!$this->getDbConnection()->getSchema()->getTable('tbl_exerciseset_exercise')) {
	$this->createTable('tbl_exerciseset_exercise', array(
		'exerciseset_id' => 'integer NOT NULL',
		'exercise_id' => 'integer NOT NULL',
		'PRIMARY KEY (exerciseset_id, exercise_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_exercise')) {
        	$this->dropTable('tbl_exercise');
        }
    }
}