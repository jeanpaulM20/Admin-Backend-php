<?php
class m120907_162016_review extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_review')) {
        	$this->createTable('tbl_review', array(
				'id' => 'pk',
				'file' => 'string NULL',
				'duration' => 'string NULL',
				'kcal' => 'integer NULL',
				'heart_rate' => 'float NULL',
				
				'exerciseset_id' => 'integer NOT NULL',
				'training_id' => 'integer NOT NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('exerciseset_id', 'tbl_review', 'exerciseset_id', false);				
			$this->createIndex('training_id', 'tbl_review', 'training_id', false);				

			
				
			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_review')) {
        	$this->dropTable('tbl_review');
        }
    }
}