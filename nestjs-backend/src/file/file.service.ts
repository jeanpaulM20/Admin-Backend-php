import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { FileEntity } from '../entities/file.entity';

@Injectable()
export class FileService {
  constructor(
    @InjectRepository(FileEntity)
    private readonly fileRepo: Repository<FileEntity>,
  ) {}

  async findByClient(clientId: number): Promise<FileEntity[]> {
    return this.fileRepo.find({
      where: { clientId },
      order: { date: 'DESC' },
    });
  }

  async findAll(): Promise<FileEntity[]> {
    return this.fileRepo.find({
      order: { date: 'DESC' },
      relations: ['client'],
    });
  }

  async findOne(id: number): Promise<FileEntity | null> {
    return this.fileRepo.findOne({ where: { id }, relations: ['client'] });
  }

  async create(data: Partial<FileEntity>): Promise<FileEntity> {
    const entity = this.fileRepo.create(data);
    return this.fileRepo.save(entity);
  }

  async update(id: number, data: Partial<FileEntity>): Promise<FileEntity | null> {
    await this.fileRepo.update(id, data);
    return this.findOne(id);
  }

  async remove(id: number): Promise<void> {
    await this.fileRepo.delete(id);
  }
}
